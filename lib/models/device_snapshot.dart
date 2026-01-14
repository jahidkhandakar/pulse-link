class DeviceSnapshot {
  final String deviceId;
  final String deviceName;
  final String model;
  final String androidVersion;

  final int batteryLevel;
  final double batteryTempC;
  final String batteryHealth; // Good / Overheat / Unknown

  final int? stepsSinceBoot;
  final String? activity; // Walking / Still / null

  final String? wifiSsid;
  final int? wifiRssi;
  final String? localIp;

  final String? carrierName;
  final int? cellularDbm;
  final String? simState;

  final DateTime timestamp;

  const DeviceSnapshot({
    required this.deviceId,
    required this.deviceName,
    required this.model,
    required this.androidVersion,
    required this.batteryLevel,
    required this.batteryTempC,
    required this.batteryHealth,
    required this.timestamp,
    this.stepsSinceBoot,
    this.activity,
    this.wifiSsid,
    this.wifiRssi,
    this.localIp,
    this.carrierName,
    this.cellularDbm,
    this.simState,
  });

  Map<String, dynamic> toJson() => {
        "deviceId": deviceId,
        "deviceName": deviceName,
        "model": model,
        "androidVersion": androidVersion,
        "batteryLevel": batteryLevel,
        "batteryTempC": batteryTempC,
        "batteryHealth": batteryHealth,
        "stepsSinceBoot": stepsSinceBoot,
        "activity": activity,
        "wifiSsid": wifiSsid,
        "wifiRssi": wifiRssi,
        "localIp": localIp,
        "carrierName": carrierName,
        "cellularDbm": cellularDbm,
        "simState": simState,
        "timestamp": timestamp.toIso8601String(),
      };

  factory DeviceSnapshot.fromJson(Map<String, dynamic> json) {
    return DeviceSnapshot(
      deviceId: _asString(json["deviceId"], fallback: "unknown"),
      deviceName: _asString(json["deviceName"], fallback: "unknown"),
      model: _asString(json["model"], fallback: "unknown"),
      androidVersion: _asString(json["androidVersion"], fallback: "unknown"),

      batteryLevel: _asInt(json["batteryLevel"], fallback: 0),
      batteryTempC: _asDouble(json["batteryTempC"], fallback: 0.0),
      batteryHealth: _asString(json["batteryHealth"], fallback: "Unknown"),

      stepsSinceBoot: _asNullableInt(json["stepsSinceBoot"]),
      activity: _asNullableString(json["activity"]),

      wifiSsid: _asNullableString(json["wifiSsid"]),
      wifiRssi: _asNullableInt(json["wifiRssi"]),
      localIp: _asNullableString(json["localIp"]),

      carrierName: _asNullableString(json["carrierName"]),
      cellularDbm: _asNullableInt(json["cellularDbm"]),
      simState: _asNullableString(json["simState"]),

      timestamp: _asDateTime(json["timestamp"]) ?? DateTime.now(),
    );
  }

  // Optional: nice short label for UI
  String get titleLabel => "$deviceName • $model";

  @override
  String toString() =>
      "DeviceSnapshot($deviceName, $model, battery=$batteryLevel%, steps=$stepsSinceBoot, ip=$localIp)";
}

// --------- Safe parsing helpers (prevent cast crashes) ---------

String _asString(dynamic v, {required String fallback}) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _asInt(dynamic v, {required int fallback}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

int? _asNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

double _asDouble(dynamic v, {required double fallback}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
