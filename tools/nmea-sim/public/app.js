'use strict';

// ── State ─────────────────────────────────────────────────────────────────────

let state = { running: false, tickMs: 2000, tcpPort: 10110, tcpClients: 0, boats: [] };

// ── WebSocket connection ───────────────────────────────────────────────────────

let ws;

function connectWS() {
  ws = new WebSocket(`ws://${location.host}`);

  ws.onopen = () => {
    const badge = document.getElementById('ws-badge');
    badge.classList.add('ok');
    badge.title = 'UI connected';
  };

  ws.onclose = () => {
    document.getElementById('ws-badge').classList.remove('ok');
    setTimeout(connectWS, 2000);
  };

  ws.onmessage = e => {
    const msg = JSON.parse(e.data);
    if (msg.type === 'state') applyState(msg);
  };
}

function send(msg) {
  if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
}

// ── State application ─────────────────────────────────────────────────────────

function applyState(newState) {
  state = newState;
  renderHeader();
  renderSidebar();
  renderMapBoats();
}

// ── Header ────────────────────────────────────────────────────────────────────

function renderHeader() {
  const playBtn = document.getElementById('btn-play');
  playBtn.textContent = state.running ? '⏸ Pause' : '▶ Play';
  playBtn.classList.toggle('live', state.running);

  const tickSel = document.getElementById('tick-select');
  if (document.activeElement !== tickSel) tickSel.value = state.tickMs;

  const tcpInfo = document.getElementById('tcp-info');
  const n = state.tcpClients;
  tcpInfo.textContent = n > 0
    ? `${n} app client${n > 1 ? 's' : ''} on :${state.tcpPort}`
    : `No app connected  (:${state.tcpPort})`;
  tcpInfo.classList.toggle('has-clients', n > 0);
}

// ── Map ───────────────────────────────────────────────────────────────────────

let map;
const markers = new Map(); // mmsi → { marker, labelContent }

function initMap() {
  map = L.map('map', { center: [41.885, -87.618], zoom: 13, zoomControl: true });

  L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 19,
  }).addTo(map);

  // Shift-click to add boat at clicked location
  map.on('click', e => {
    if (e.originalEvent.shiftKey) {
      send({ type: 'addBoat', boat: { lat: e.latlng.lat, lon: e.latlng.lng } });
    }
  });
}

function boatIcon(heading, name, sog) {
  const angle = (heading || 0).toFixed(0);
  const label = `${name}  ${sog.toFixed(1)}kn`;
  return L.divIcon({
    className: '',
    html: `
      <div class="boat-marker-wrap">
        <div class="boat-marker-arrow" style="transform:rotate(${angle}deg)">
          <svg viewBox="0 0 20 28" width="20" height="28">
            <polygon points="10,1 19,26 10,21 1,26"
              fill="#4fc3f7" stroke="rgba(255,255,255,0.75)" stroke-width="1.2"
              stroke-linejoin="round"/>
          </svg>
        </div>
        <div class="boat-marker-label">${escHtml(label)}</div>
      </div>`,
    iconSize: [100, 50],
    iconAnchor: [50, 20],
  });
}

function renderMapBoats() {
  const current = new Set(state.boats.map(b => b.mmsi));

  // Remove stale markers
  for (const [mmsi, m] of markers) {
    if (!current.has(mmsi)) { m.marker.remove(); markers.delete(mmsi); }
  }

  for (const boat of state.boats) {
    if (!markers.has(boat.mmsi)) {
      const marker = L.marker([boat.lat, boat.lon], {
        icon: boatIcon(boat.heading, boat.name, boat.sog),
        draggable: true,
      }).addTo(map);

      marker.on('dragend', e => {
        const ll = e.target.getLatLng();
        send({ type: 'moveBoat', mmsi: boat.mmsi, lat: ll.lat, lon: ll.lng });
      });

      markers.set(boat.mmsi, { marker });
    } else {
      const { marker } = markers.get(boat.mmsi);
      marker.setLatLng([boat.lat, boat.lon]);
      marker.setIcon(boatIcon(boat.heading, boat.name, boat.sog));
    }
  }
}

function panToBoat(mmsi) {
  const boat = state.boats.find(b => b.mmsi === mmsi);
  if (boat) map.panTo([boat.lat, boat.lon]);
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

function renderSidebar() {
  const list = document.getElementById('boat-list');

  // Build lookup of existing cards
  const existingCards = new Map();
  for (const el of list.querySelectorAll('.boat-card')) {
    existingCards.set(Number(el.dataset.mmsi), el);
  }

  const seen = new Set();
  for (const boat of state.boats) {
    seen.add(boat.mmsi);
    if (existingCards.has(boat.mmsi)) {
      refreshCard(existingCards.get(boat.mmsi), boat);
    } else {
      const card = buildCard(boat);
      list.appendChild(card);
    }
  }

  // Prune removed boats
  for (const [mmsi, el] of existingCards) {
    if (!seen.has(mmsi)) el.remove();
  }

  // Empty state
  let emptyEl = list.querySelector('.sidebar-empty');
  if (state.boats.length === 0) {
    if (!emptyEl) {
      emptyEl = document.createElement('div');
      emptyEl.className = 'sidebar-empty';
      emptyEl.innerHTML = '<div class="icon">⚓</div><div>No boats — click ＋ Add Boat<br>or Shift-click the map</div>';
      list.appendChild(emptyEl);
    }
  } else if (emptyEl) {
    emptyEl.remove();
  }
}

// ── Boat card builder ─────────────────────────────────────────────────────────

function buildCard(boat) {
  const card = document.createElement('div');
  card.className = 'boat-card';
  card.dataset.mmsi = boat.mmsi;
  card.innerHTML = cardHTML(boat);
  bindCardEvents(card, boat.mmsi);
  return card;
}

function cardHTML(boat) {
  return `
    <div class="card-header">
      <span class="boat-icon">⛵</span>
      <input class="name-input" type="text" value="${escHtml(boat.name)}"
             placeholder="Vessel name" title="Vessel name (sent via AIS type 5)">
      <span class="mmsi-badge">${boat.mmsi}</span>
      <button class="btn-focus" title="Pan map to boat">◎</button>
      <button class="btn-remove" title="Remove boat">✕</button>
    </div>

    <div class="card-body">

      <div class="field-row">
        <span class="field-label">SOG</span>
        <input type="range" class="sog-slider" min="0" max="20" step="0.1"
               value="${boat.sog.toFixed(1)}">
        <span class="field-val sog-val">${boat.sog.toFixed(1)} kn</span>
      </div>

      <div class="compass-wrap">
        ${compassSVG(boat.heading)}
        <div class="compass-fields">
          <div class="field-row">
            <span class="field-label">COG</span>
            <input type="range" class="cog-slider" min="0" max="359" step="1"
                   value="${Math.round(boat.cog)}">
            <span class="field-val cog-val">${Math.round(boat.cog)}°</span>
          </div>
          <div class="field-row">
            <span class="field-label">HDG</span>
            <input type="range" class="hdg-slider" min="0" max="359" step="1"
                   value="${Math.round(boat.heading)}">
            <span class="field-val hdg-val">${Math.round(boat.heading)}°</span>
          </div>
          <div class="pos-display">
            <span class="lat-val">${formatLat(boat.lat)}</span>
            <span class="lon-val">${formatLon(boat.lon)}</span>
          </div>
        </div>
      </div>

    </div>`;
}

/** Refresh only the dynamic parts of an existing card (never rebuild whole DOM). */
function refreshCard(card, boat) {
  const sogSlider = card.querySelector('.sog-slider');
  const cogSlider = card.querySelector('.cog-slider');
  const hdgSlider = card.querySelector('.hdg-slider');
  const nameInput = card.querySelector('.name-input');

  if (document.activeElement !== sogSlider)  sogSlider.value = boat.sog.toFixed(1);
  if (document.activeElement !== cogSlider)  cogSlider.value = Math.round(boat.cog);
  if (document.activeElement !== hdgSlider)  hdgSlider.value = Math.round(boat.heading);
  if (document.activeElement !== nameInput)  nameInput.value = boat.name;

  card.querySelector('.sog-val').textContent = `${boat.sog.toFixed(1)} kn`;
  card.querySelector('.cog-val').textContent = `${Math.round(boat.cog)}°`;
  card.querySelector('.hdg-val').textContent = `${Math.round(boat.heading)}°`;
  card.querySelector('.lat-val').textContent  = formatLat(boat.lat);
  card.querySelector('.lon-val').textContent  = formatLon(boat.lon);

  // Update compass needle
  const needle = card.querySelector('.compass-needle');
  if (needle) needle.setAttribute('transform', `rotate(${Math.round(boat.heading)}, 32, 32)`);
}

// ── Card event bindings ───────────────────────────────────────────────────────

function bindCardEvents(card, mmsi) {
  card.querySelector('.name-input').addEventListener('change', e => {
    send({ type: 'updateBoat', mmsi, update: { name: e.target.value.trim() || `VESSEL ${mmsi % 10000}` } });
  });

  card.querySelector('.sog-slider').addEventListener('input', e => {
    const sog = parseFloat(e.target.value);
    card.querySelector('.sog-val').textContent = `${sog.toFixed(1)} kn`;
    send({ type: 'updateBoat', mmsi, update: { sog } });
  });

  card.querySelector('.cog-slider').addEventListener('input', e => {
    const cog = parseInt(e.target.value, 10);
    card.querySelector('.cog-val').textContent = `${cog}°`;
    send({ type: 'updateBoat', mmsi, update: { cog } });
  });

  card.querySelector('.hdg-slider').addEventListener('input', e => {
    const heading = parseInt(e.target.value, 10);
    card.querySelector('.hdg-val').textContent = `${heading}°`;
    const needle = card.querySelector('.compass-needle');
    if (needle) needle.setAttribute('transform', `rotate(${heading}, 32, 32)`);
    send({ type: 'updateBoat', mmsi, update: { heading } });
  });

  card.querySelector('.btn-remove').addEventListener('click', () => {
    send({ type: 'removeBoat', mmsi });
  });

  card.querySelector('.btn-focus').addEventListener('click', () => {
    panToBoat(mmsi);
  });

  // Compass drag to set heading
  bindCompassDrag(card.querySelector('.compass'), mmsi, card);
}

// ── Compass SVG ───────────────────────────────────────────────────────────────

function compassSVG(heading) {
  const ticks = [0, 45, 90, 135, 180, 225, 270, 315].map(a => {
    const r = a * Math.PI / 180;
    const x1 = 32 + 24 * Math.sin(r);
    const y1 = 32 - 24 * Math.cos(r);
    const x2 = 32 + 28 * Math.sin(r);
    const y2 = 32 - 28 * Math.cos(r);
    return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}"
              stroke="rgba(79,195,247,0.25)" stroke-width="1"/>`;
  }).join('');

  return `
  <svg class="compass" viewBox="0 0 64 64" width="64" height="64" title="Drag to set heading">
    <circle cx="32" cy="32" r="30" fill="#0e1d33" stroke="rgba(79,195,247,0.2)" stroke-width="1.5"/>
    ${ticks}
    <text x="32" y="8"  text-anchor="middle" fill="rgba(79,195,247,0.7)" font-size="7" font-weight="bold">N</text>
    <text x="58" y="35" text-anchor="middle" fill="rgba(79,195,247,0.4)" font-size="6">E</text>
    <text x="32" y="60" text-anchor="middle" fill="rgba(79,195,247,0.4)" font-size="6">S</text>
    <text x="6"  y="35" text-anchor="middle" fill="rgba(79,195,247,0.4)" font-size="6">W</text>
    <g class="compass-needle" transform="rotate(${Math.round(heading)}, 32, 32)">
      <polygon points="32,8 36,44 32,40 28,44"
               fill="#4fc3f7" stroke="rgba(255,255,255,0.5)" stroke-width="0.8"
               stroke-linejoin="round"/>
    </g>
    <circle cx="32" cy="32" r="3" fill="#4fc3f7" opacity="0.6"/>
  </svg>`;
}

function bindCompassDrag(compassEl, mmsi, card) {
  if (!compassEl) return;
  let dragging = false;

  function angleFromEvent(e) {
    const rect = compassEl.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    let angle = Math.atan2(clientX - cx, -(clientY - cy)) * 180 / Math.PI;
    if (angle < 0) angle += 360;
    return Math.round(angle) % 360;
  }

  function onMove(e) {
    if (!dragging) return;
    e.preventDefault();
    const heading = angleFromEvent(e);
    const needle = card.querySelector('.compass-needle');
    if (needle) needle.setAttribute('transform', `rotate(${heading}, 32, 32)`);
    card.querySelector('.hdg-val').textContent = `${heading}°`;
    const hdgSlider = card.querySelector('.hdg-slider');
    if (document.activeElement !== hdgSlider) hdgSlider.value = heading;
    send({ type: 'updateBoat', mmsi, update: { heading } });
  }

  function onUp() { dragging = false; }

  compassEl.addEventListener('mousedown',  e => { dragging = true; onMove(e); });
  compassEl.addEventListener('touchstart', e => { dragging = true; onMove(e); }, { passive: false });
  document.addEventListener('mousemove',   onMove);
  document.addEventListener('touchmove',   onMove, { passive: false });
  document.addEventListener('mouseup',     onUp);
  document.addEventListener('touchend',    onUp);
}

// ── Formatting helpers ────────────────────────────────────────────────────────

function formatLat(lat) {
  const d = Math.abs(lat).toFixed(4);
  return `${d}° ${lat >= 0 ? 'N' : 'S'}`;
}

function formatLon(lon) {
  const d = Math.abs(lon).toFixed(4);
  return `${d}° ${lon >= 0 ? 'E' : 'W'}`;
}

function escHtml(str) {
  return String(str).replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  initMap();
  connectWS();

  document.getElementById('btn-play').addEventListener('click', () => {
    send({ type: 'setRunning', running: !state.running });
  });

  document.getElementById('btn-add').addEventListener('click', () => {
    const center = map.getCenter();
    send({ type: 'addBoat', boat: { lat: center.lat, lon: center.lng } });
  });

  document.getElementById('tick-select').addEventListener('change', e => {
    send({ type: 'setTickMs', tickMs: parseInt(e.target.value, 10) });
  });
});
