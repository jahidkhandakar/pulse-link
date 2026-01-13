# Technical Decisions – PulseLink

This document explains key architectural and technical decisions made during development, along with known limitations.

---

## Platform Scope
- Target platform: **Android**
- Reason: The task requires deep access to Android-specific sensors and networking APIs.

---

## Android SDK Configuration
- **minSdkVersion:** 21  
- **targetSdkVersion:** 35  
- **compileSdkVersion:** 35  

**Rationale:**  
minSdk 21 ensures compatibility with required sensors and networking APIs.  
targetSdk and compileSdk 35 align with modern Android security and Google Play requirements.

---

## Data Collection Strategy
All device and health data is collected using **Android native APIs** via Flutter `MethodChannel`.

**Examples:**
- Battery status: `BatteryManager`
- Step count: `Sensor.TYPE_STEP_COUNTER`
- Activity detection: Android Activity Recognition APIs
- Wi-Fi info: `WifiManager`, `ConnectivityManager`
- Carrier & signal: `TelephonyManager`

No mock or simulated data is used.

---

## Local Network Discovery
- **Approach:** Android Network Service Discovery (NSD / mDNS)
- **Protocol:** TCP sockets over local Wi-Fi

**Rationale:**  
NSD enables automatic peer discovery on the same Wi-Fi network without requiring manual IP entry or external servers.

---

## Data Sharing
- Device snapshots are serialized as JSON.
- Data is transmitted directly peer-to-peer using TCP sockets.
- No relay servers, cloud services, or third-party networking frameworks are used.

---

## Local Persistence
- **Chosen solution:** Hive

**Rationale:**  
Hive provides fast, lightweight local storage for structured data with minimal boilerplate.  
It is well-suited for persisting received device snapshots across app restarts.

---

## Limitations & Notes
- Some telephony signal metrics may be restricted on certain Android versions or devices.
- Activity recognition availability depends on device support and user permissions.
- Wi-Fi SSID access requires location permission on Android 10+.

These constraints are documented and handled gracefully in the UI.
