# PulseLink (Flutter + Android)

PulseLink is a Flutter-based Android application that collects **real, live device and sensor data** and enables **instant peer-to-peer sharing** with nearby devices on the same Wi-Fi network — without servers, cloud services, or mocked values.

This project was built as a technical assessment to demonstrate native Android integrations, sensor handling, and local networking using Flutter.

---

## Key Features

### Live Device Snapshot (Real Data Only)
- Device info: name, model, Android version
- Battery: level (%), temperature (°C), health status
- Steps since last device boot (hardware step counter)
- Activity detection: **Walking / Still**
- Wi-Fi: SSID, RSSI, local IPv4 address
- Cellular: carrier name, SIM state, signal strength (dBm, best-effort)

> No mock or simulated data is used.  
> If a value is unavailable, the UI shows `-`.

---

### Local Peer Discovery & Sharing
- Automatic peer discovery on the same Wi-Fi using **Android NSD (mDNS/DNS-SD)**
- Direct **TCP socket** communication (no servers, no manual IPs)
- Tap a peer → instantly send your current snapshot
- Incoming snapshots are received in real time

---

### Received Data History
- Incoming snapshots are persisted locally using **Hive**
- Data survives app restarts
- View recent snapshots (newest first)
- Tap to view details; raw payload available via button
- Optional history cap to avoid unbounded storage growth

---

## How to Run

1. Clone the repository
2. Run:
   ```bash
   flutter pub get

## Tech Stack
- Flutter (UI + state)
- Kotlin (native Android integration)
- Android Sensors API
- Android NSD (mDNS/DNS-SD)
- TCP sockets
- Hive (local persistence)


> Devices must be connected to the same Wi-Fi network for peer discovery and sharing.