## Implemented: Native Snapshot v1 (Device + Battery)
- Added `DeviceSnapshot` model in Flutter to represent all sensor/network fields.
- Implemented `MethodChannel` (`com.pulselink/native`) and `getSnapshot` method.
- Android side collects real battery data via `ACTION_BATTERY_CHANGED` (level %, temperature °C, health mapping).
- Device metadata collected from `Build.*` + `Settings.Global.DEVICE_NAME` (when available).
- Dashboard UI refreshes snapshot every 2 seconds and displays device + battery cards.
- Other fields are currently `null` (explicitly not mocked); will be populated in next iterations.


## Implemented: Step Count (since device boot)
- Integrated Android `Sensor.TYPE_STEP_COUNTER` via `SensorManager`.
- `MainActivity` registers a `SensorEventListener` in `onResume` and unregisters in `onPause`.
- Latest step count (since last device boot) is cached in-memory and included in `getSnapshot()`.
- If the device has no step counter sensor (or emulator), the field remains `null` and UI shows `-` (no mocked values).


## Implemented: Wi-Fi SSID / RSSI / Local IP (Real Data)
- Added Android Wi-Fi collection using `WifiManager.connectionInfo` for SSID and RSSI.
- Implemented robust local IPv4 detection via `NetworkInterface` enumeration (avoids `0.0.0.0` cases).
- Added runtime permission flow via MethodChannel:
  - Requests `ACCESS_FINE_LOCATION` (required for SSID access on Android 10+).
  - Requests `NEARBY_WIFI_DEVICES` on Android 13+.
- If permissions are denied/unavailable, Wi-Fi fields remain `null` and UI displays `-` (no mocked data).


## Implemented: Carrier / SIM State / Cellular Signal (dBm)
- Added Telephony integration using `TelephonyManager` for carrier name and SIM state.
- Implemented best-effort signal strength (dBm) listener:
  - API 31+ uses `TelephonyCallback.SignalStrengthsListener`.
  - Older APIs use `PhoneStateListener`.
- Added runtime permission flow via MethodChannel for `READ_PHONE_STATE`.
- If permissions are denied or device/OEM restricts signal APIs, `cellularDbm` remains `null` (no mocked values).


## Implemented: Detected Activity (Walking / Still) via Sensors
- Implemented activity classification using real device sensors only (no Google Play Services):
  - Step trend from `Sensor.TYPE_STEP_COUNTER` (steps since boot) sampled over a short window.
  - Motion signal from `Sensor.TYPE_ACCELEROMETER` using acceleration magnitude and EMA smoothing.
- Activity label is derived from thresholds:
  - "Walking" when recent step delta increases or motion EMA is high.
  - "Still" when motion EMA is low (and/or no step change).
  - `null` when no reliable sensor signal is available yet.
- No mock values are used; the UI displays `-` when unavailable.


## Implemented: Local Peer Discovery + Sharing (NSD/mDNS + TCP)
- Added peer-to-peer networking without servers using Android NSD (mDNS/DNS-SD) on the same Wi-Fi network.
- Each device:
  - Starts a local TCP server on an ephemeral port.
  - Registers `_pulselink._tcp.` service via NSD with service name `PulseLink-<deviceId>`.
  - Discovers and resolves other services to obtain peer IP + port automatically (no manual IP entry).
- Sending:
  - Flutter sends current snapshot JSON to selected peer over TCP.
- Receiving:
  - TCP server reads incoming JSON payload and forwards it to Flutter via `EventChannel` (`com.pulselink/events/received`).
- Peer list updates are streamed to Flutter via `EventChannel` (`com.pulselink/events/peers`).
