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
