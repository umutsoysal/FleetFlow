'use strict';
// ─── FleetFlow NMEA Simulator ─────────────────────────────────────────────────
// Development harness — NOT for production use.
//
//  TCP :10110  →  NMEA 0183 AIS stream  (connect FleetFlow to 127.0.0.1:10110)
//  HTTP :3000  →  Simulator web UI
// ─────────────────────────────────────────────────────────────────────────────

const express   = require('express');
const { WebSocketServer } = require('ws');
const net       = require('net');
const path      = require('path');
const http      = require('http');

// ── AIS 6-bit encoding ────────────────────────────────────────────────────────

/** ASCII char → AIS 6-bit value */
function charToAIS6(c) {
  const code = c.charCodeAt(0);
  return (code >= 64 ? code - 64 : code) & 0x3f;
}

/**
 * Pack an array of field descriptors into a flat bit array (MSB first).
 *   { value: number, bits: number, signed?: boolean }
 *   { text:  string, bits: number }   — bits must be a multiple of 6
 */
function packFields(fields) {
  const out = [];
  for (const f of fields) {
    if ('text' in f) {
      const chars = f.bits / 6;
      const s = f.text.toUpperCase().substring(0, chars).padEnd(chars, '@');
      for (let i = 0; i < chars; i++) {
        const v = charToAIS6(s[i]);
        for (let b = 5; b >= 0; b--) out.push((v >> b) & 1);
      }
    } else {
      const b = f.bits;
      let v = (f.signed && f.value < 0) ? f.value + (1 << b) : f.value;
      v = v & ((1 << b) - 1);
      for (let i = b - 1; i >= 0; i--) out.push((v >> i) & 1);
    }
  }
  return out;
}

/** Bit array → NMEA payload string (pads to multiple of 6 with zero bits). */
function bitsToPayload(bits) {
  const padded = [...bits];
  while (padded.length % 6) padded.push(0);
  let s = '';
  for (let i = 0; i < padded.length; i += 6) {
    let v = 0;
    for (let j = 0; j < 6; j++) v = (v << 1) | padded[i + j];
    let c = v + 48;
    if (c > 87) c += 8;
    s += String.fromCharCode(c);
  }
  return s;
}

/** XOR checksum over characters between ! and * (exclusive). */
function nmeaChecksum(body) {
  let x = 0;
  for (let i = 0; i < body.length; i++) x ^= body.charCodeAt(i);
  return x.toString(16).toUpperCase().padStart(2, '0');
}

/** Wrap payload in a single-part !AIVDM sentence. */
function vdmSentence(payload, fillBits) {
  const body = `AIVDM,1,1,,A,${payload},${fillBits}`;
  return `!${body}*${nmeaChecksum(body)}\r\n`;
}

/**
 * AIS Message Type 1 — Class A Position Report
 * 168 bits → 28 payload chars, 0 fill bits
 */
function encodePositionReport(boat) {
  const bits = packFields([
    { value: 1,                                                bits: 6  },
    { value: 0,                                                bits: 2  },
    { value: boat.mmsi,                                        bits: 30 },
    { value: 8,                                                bits: 4  }, // underway sailing
    { value: 128,                                              bits: 8  }, // ROT not available
    { value: Math.min(1022, Math.round(boat.sog * 10)),        bits: 10 },
    { value: 0,                                                bits: 1  }, // position accuracy
    { value: Math.round(boat.lon * 600000), signed: true,      bits: 28 },
    { value: Math.round(boat.lat * 600000), signed: true,      bits: 27 },
    { value: Math.round(boat.cog * 10) % 3600,                 bits: 12 },
    { value: Math.round(boat.heading) % 360,                   bits: 9  },
    { value: new Date().getUTCSeconds(),                       bits: 6  },
    { value: 0,                                                bits: 2  }, // special maneuver
    { value: 0,                                                bits: 3  }, // spare
    { value: 0,                                                bits: 1  }, // RAIM
    { value: 0,                                                bits: 19 }, // radio status
  ]);
  return vdmSentence(bitsToPayload(bits), 0);
}

/**
 * AIS Message Type 5 — Static and Voyage Related Data
 * 424 bits → 71 payload chars, 2 fill bits
 * NOTE: FleetFlow only stores name/callSign if a position report for this
 * MMSI has already been received, so always send pos-report first.
 */
function encodeStaticData(boat) {
  const bits = packFields([
    { value: 5,                                                bits: 6   },
    { value: 0,                                                bits: 2   },
    { value: boat.mmsi,                                        bits: 30  },
    { value: 0,                                                bits: 2   }, // AIS version
    { value: 0,                                                bits: 30  }, // IMO
    { text: (boat.callSign || '').substring(0, 7).padEnd(7, '@'), bits: 42 },
    { text: (boat.name     || '').substring(0, 20).padEnd(20, '@'), bits: 120 },
    { value: 36,                                               bits: 8   }, // sailing vessel
    { value: 0,                                                bits: 9   }, // dim bow
    { value: 0,                                                bits: 9   }, // dim stern
    { value: 0,                                                bits: 6   }, // dim port
    { value: 0,                                                bits: 6   }, // dim starboard
    { value: 1,                                                bits: 4   }, // EPFS: GPS
    { value: 0,                                                bits: 4   }, // ETA month
    { value: 0,                                                bits: 5   }, // ETA day
    { value: 24,                                               bits: 5   }, // ETA hour
    { value: 60,                                               bits: 6   }, // ETA minute
    { value: 0,                                                bits: 8   }, // draught
    { text: '@'.repeat(20),                                    bits: 120 }, // destination
    { value: 1,                                                bits: 1   }, // DTE
    { value: 0,                                                bits: 1   }, // spare
  ]);
  return vdmSentence(bitsToPayload(bits), 2);
}

// ── Dead reckoning ────────────────────────────────────────────────────────────

const DEG2RAD = Math.PI / 180;

function advanceBoat(boat, dtSeconds) {
  if (boat.sog <= 0) return;
  const distNM = boat.sog * (dtSeconds / 3600);
  const hdRad  = boat.cog * DEG2RAD;
  boat.lat += distNM * Math.cos(hdRad) / 60;
  const cosLat = Math.cos(boat.lat * DEG2RAD);
  boat.lon += distNM * Math.sin(hdRad) / (60 * Math.max(0.001, cosLat));
}

// ── Boat registry ─────────────────────────────────────────────────────────────

let _nextMMSI = 100000001;
const boats   = new Map(); // mmsi → boat

function createBoat(overrides = {}) {
  const mmsi = _nextMMSI++;
  const boat = {
    mmsi,
    name:     `VESSEL ${mmsi % 10000}`,
    callSign: `SIM${mmsi % 1000}`,
    lat:  41.885 + (Math.random() - 0.5) * 0.06,
    lon: -87.618 + (Math.random() - 0.5) * 0.06,
    sog:     6,
    cog:    45,
    heading: 45,
    isOwn:  false,
    ...overrides,
  };
  boats.set(boat.mmsi, boat);
  return boat;
}

// Seed boats matching the FleetFlow mock data area (Lake Michigan, Chicago)
createBoat({ name: 'WIND DANCER',   callSign: 'WD01', lat: 41.8850, lon: -87.6180, sog: 7.2, cog: 45,  heading: 45  });
createBoat({ name: 'BLUE HORIZON',  callSign: 'BH01', lat: 41.8900, lon: -87.6100, sog: 6.8, cog: 52,  heading: 52  });
createBoat({ name: 'SWIFT CURRENT', callSign: 'SC01', lat: 41.8780, lon: -87.6250, sog: 8.1, cog: 38,  heading: 38  });
createBoat({ mmsi: 235001001, name: "ESPRIT D'ECOSSE", callSign: 'EDE01',
             lat: 41.8830, lon: -87.6200, sog: 6.5, cog: 50, heading: 50, isOwn: true });

// ── TCP server :10110 ─────────────────────────────────────────────────────────

const TCP_PORT   = 10110;
const tcpClients = new Set();

const tcpServer = net.createServer(socket => {
  const addr = `${socket.remoteAddress}:${socket.remotePort}`;
  console.log(`[TCP] + ${addr}`);
  tcpClients.add(socket);

  // Greet new client: position first so FleetFlow creates the boat record,
  // then static data so it can store the name.
  for (const boat of boats.values()) {
    writeTCP(socket, encodePositionReport(boat));
    writeTCP(socket, encodeStaticData(boat));
  }
  broadcastUI();

  socket.on('close', () => {
    tcpClients.delete(socket);
    console.log(`[TCP] - ${addr}`);
    broadcastUI();
  });
  socket.on('error', () => tcpClients.delete(socket));
});

tcpServer.listen(TCP_PORT, () =>
  console.log(`[TCP]  NMEA server  →  :${TCP_PORT}`)
);

function writeTCP(socket, data) {
  try { if (!socket.destroyed) socket.write(data); } catch (_) {}
}

function broadcastTCP(data) {
  for (const s of tcpClients) writeTCP(s, data);
}

// ── Simulation tick ───────────────────────────────────────────────────────────

let running      = true;
let tickMs       = 2000;
let tickCount    = 0;
let lastTickTime = Date.now();
let _timer       = null;

function tick() {
  _timer = null;
  const now = Date.now();
  const dt  = (now - lastTickTime) / 1000;
  lastTickTime = now;
  tickCount++;

  for (const boat of boats.values()) {
    advanceBoat(boat, dt);
    broadcastTCP(encodePositionReport(boat));
    // Resend static data every 10 ticks (~20s at 2s/tick)
    if (tickCount % 10 === 0) broadcastTCP(encodeStaticData(boat));
  }

  broadcastUI();
  if (running) _timer = setTimeout(tick, tickMs);
}

function startTick() {
  if (_timer) return;
  lastTickTime = Date.now();
  _timer = setTimeout(tick, tickMs);
}

function stopTick() {
  if (_timer) { clearTimeout(_timer); _timer = null; }
}

startTick();

// ── HTTP + WebSocket server :3000 ─────────────────────────────────────────────

const app        = express();
const httpServer = http.createServer(app);
const wss        = new WebSocketServer({ server: httpServer });

app.use(express.static(path.join(__dirname, 'public')));

// Proxy map tiles server-side so the browser never makes cross-origin requests
// (avoids ORB blocking in Chromium-based embedded browsers).
// Tiles are cached in memory for the session to avoid hammering the CDN.
const tileCache = new Map();

app.get('/tiles/:z/:x/:y', async (req, res) => {
  const { z, x, y } = req.params;
  const key = `${z}/${x}/${y}`;
  if (tileCache.has(key)) {
    res.set('Content-Type', 'image/png');
    res.set('Cache-Control', 'public, max-age=86400');
    return res.send(tileCache.get(key));
  }
  const sub = 'abcd'[Math.floor(Math.random() * 4)];
  const url = `https://${sub}.basemaps.cartocdn.com/dark_all/${z}/${x}/${y}.png`;
  try {
    const upstream = await fetch(url, {
      headers: { 'User-Agent': 'FleetFlow-Simulator/1.0 (dev tool)' },
    });
    if (!upstream.ok) return res.status(upstream.status).end();
    const buf = Buffer.from(await upstream.arrayBuffer());
    tileCache.set(key, buf);
    res.set('Content-Type', 'image/png');
    res.set('Cache-Control', 'public, max-age=86400');
    res.send(buf);
  } catch (e) {
    res.status(502).end();
  }
});

function snapshot() {
  return {
    type:       'state',
    running,
    tickMs,
    tcpPort:    TCP_PORT,
    tcpClients: tcpClients.size,
    boats:      [...boats.values()],
  };
}

function broadcastUI() {
  const msg = JSON.stringify(snapshot());
  for (const ws of wss.clients) {
    if (ws.readyState === 1 /* OPEN */) ws.send(msg);
  }
}

wss.on('connection', ws => {
  ws.send(JSON.stringify(snapshot()));

  ws.on('message', raw => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }

    switch (msg.type) {
      case 'addBoat': {
        const boat = createBoat(msg.boat ?? {});
        for (const s of tcpClients) {
          writeTCP(s, encodePositionReport(boat));
          writeTCP(s, encodeStaticData(boat));
        }
        broadcastUI();
        break;
      }

      case 'updateBoat': {
        const boat = boats.get(msg.mmsi);
        if (!boat) break;
        const nameChanged = msg.update.name !== undefined && msg.update.name !== boat.name;
        Object.assign(boat, msg.update);
        boat.sog     = Math.max(0, Math.min(30, boat.sog));
        boat.cog     = ((boat.cog     % 360) + 360) % 360;
        boat.heading = ((boat.heading % 360) + 360) % 360;
        if (nameChanged) {
          for (const s of tcpClients) {
            writeTCP(s, encodePositionReport(boat));
            writeTCP(s, encodeStaticData(boat));
          }
        }
        broadcastUI();
        break;
      }

      case 'removeBoat':
        boats.delete(msg.mmsi);
        broadcastUI();
        break;

      case 'moveBoat': {
        const boat = boats.get(msg.mmsi);
        if (boat) { boat.lat = msg.lat; boat.lon = msg.lon; }
        broadcastUI();
        break;
      }

      case 'setRunning':
        running = !!msg.running;
        running ? startTick() : stopTick();
        broadcastUI();
        break;

      case 'setTickMs':
        tickMs = Math.max(500, Math.min(10000, msg.tickMs | 0));
        broadcastUI();
        break;
    }
  });
});

const HTTP_PORT = 3000;
httpServer.listen(HTTP_PORT, () => {
  console.log(`[HTTP] Simulator UI   →  http://localhost:${HTTP_PORT}`);
  console.log(`\n  In FleetFlow settings, set host = 127.0.0.1  port = ${TCP_PORT}\n`);
});
