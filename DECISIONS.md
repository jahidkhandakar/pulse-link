# Technical Decisions – PulseLink

This document outlines key architectural decisions and known limitations.

---

## Platform Scope
- Target platform: **Android only**

**Reason:**  
The task requires direct access to Android-specific sensors, telephony APIs, and local networking features that are not consistently available across platforms.

---

## Android SDK Configuration
- **minSdkVersion:** 21  
- **targetSdkVersion:** 36  
- **compileSdkVersion:** 36  

**Rationale:**  
minSdk 21 ensures compatibility with required sensors and networking APIs.  
targetSdk and compileSdk 35 align with modern Android security and Play Store requirements.

---

## Data Collection Strategy
All data is collected using **native Android APIs** via Flutter `MethodChannel`.

**Examples:**
- Battery: `BatteryManager`, `ACTION_BATTERY_CHANGED`
- Steps: `Sensor.TYPE_STEP_COUNTER`
- Activity: Accelerometer + step trend analysis
- Wi-Fi: `WifiManager`, `NetworkInterface`
- Telephony: `TelephonyManager`

No mock or simulated values are used.

---

## Peer Discovery & Networking
- **Approach:** Android Network Service Discovery (NSD / mDNS)
- **Transport:** TCP sockets over local Wi-Fi

**Rationale:**  
NSD enables zero-configuration peer discovery without manual IP entry or external infrastructure.

---

## Data Sharing
- Snapshots serialized as JSON.
- Direct peer-to-peer transmission via TCP.
- No cloud services, relays, or third-party networking frameworks.

---

## Local Persistence
- **Chosen solution:** Hive

**Rationale:**  
Hive is lightweight, fast, and well-suited for storing structured data locally with minimal boilerplate.  
It avoids database schema complexity for this use case.

---

## Limitations & Notes
- Cellular signal strength may be restricted by Android version or OEM implementation.
- Activity detection accuracy depends on available sensors and device motion.
- Wi-Fi SSID access requires location permission and location services enabled on Android 10+.

All limitations are handled gracefully and reflected transparently in the UI.
