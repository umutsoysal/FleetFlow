---
name: dev-workflow
description: 'FleetFlow development workflow: how to run the NMEA simulator, how to run the Flutter app, and how to connect them. Use when asked about running the app locally, starting the simulator, connecting to the simulator, development setup, local testing, or debugging the AIS feed.'
argument-hint: 'Optional: target platform (iOS, Android, macOS, web)'
---

# FleetFlow Dev Workflow

## Overview

FleetFlow connects to a live NMEA/AIS TCP stream at `host:10110`.
During development, the bundled simulator (`tools/nmea-sim/`) replaces the real B&G chartplotter.

```
[tools/nmea-sim]  ──TCP :10110──►  [FleetFlow app]
     HTTP :3000 → control UI
```

---

## 1. Start the Simulator

```bash
cd tools/nmea-sim
npm install        # first time only
npm start
```

| Service | Address | Purpose |
|---------|---------|---------|
| AIS TCP stream | `127.0.0.1:10110` | What the app connects to |
| Web control UI | `http://localhost:3000` | Add/move/edit simulated boats |

Leave this terminal running for the duration of your dev session.

---

## 2. Run the Flutter App

From the repo root:

```bash
flutter pub get    # first time or after pubspec.yaml changes
flutter run        # picks a connected device/simulator automatically
```

Target a specific platform:

```bash
flutter run -d macos          # macOS desktop
flutter run -d chrome         # Flutter web
flutter run -d <device-id>    # iOS/Android — get IDs with: flutter devices
```

---

## 3. Connect the App to the Simulator

The default host is `192.168.1.1` (real chartplotter). Change it to point at the simulator.

### Which address to use

| Where the app is running | Host to enter |
|--------------------------|---------------|
| iOS/Android **emulator** on the same Mac | `127.0.0.1` |
| macOS / web on the same Mac | `127.0.0.1` |
| iOS/Android **physical device** on same Wi-Fi | Mac's LAN IP (find with `ipconfig getifaddr en0`) |

Port is always `10110`.

### Steps in the app

1. Open the **Connection Settings** sheet (gear icon on the dashboard).
2. Set **Host** to `127.0.0.1` (or Mac LAN IP for physical device).
3. Set **Port** to `10110`.
4. Tap **Connect**.

The status indicator in the app header turns green when the TCP connection is established and AIS sentences start arriving.

---

## 4. Troubleshooting

**App can't connect from a physical device**
macOS Firewall may be blocking the incoming TCP connection.
System Settings → Network → Firewall → allow `node`, or temporarily disable.

**Simulator exits immediately**
`node` not installed or `npm install` not run yet. Verify with `node --version`.

**No boats appearing after connecting**
Open `http://localhost:3000` and check that the simulator has boats defined.
The app only renders vessels once it receives valid AIS Type 1/2/3 or Type 5 sentences.

**Port 10110 already in use**
```bash
lsof -i :10110   # find the occupying process
kill <PID>
```

**Port 3000 already in use**
The simulator web UI won't start but the TCP AIS feed on :10110 is independent — the app will still work.

---

## 5. Useful Commands

```bash
# List available Flutter devices
flutter devices

# Watch for Dart errors while running
flutter run --verbose

# Hot reload (in running flutter run session)
r        # hot reload
R        # hot restart
q        # quit

# Verify simulator is broadcasting
nc -v 127.0.0.1 10110   # should print NMEA sentences
```
