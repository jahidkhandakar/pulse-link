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
