class DeviceSnapshot {
  final String deviceId;
  final String deviceName;
  final String model;
  final String androidVersion;

  final int batteryLevel;
  final double batteryTempC;
  final String batteryHealth; // Good / Overheat / Unknown

  final int? stepsSinceBoot;
  final String? activity; // Walking / Still / Unknown

  final String? wifiSsid;
  final int? wifiRssi;
  final String? localIp;

  final String? carrierName;
  final int? cellularDbm;
  final String? simState;

  final DateTime timestamp;

  DeviceSnapshot({
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

  factory DeviceSnapshot.fromJson(Map<String, dynamic> json) => DeviceSnapshot(
        deviceId: json["deviceId"] ?? "unknown",
        deviceName: json["deviceName"] ?? "unknown",
        model: json["model"] ?? "unknown",
        androidVersion: json["androidVersion"] ?? "unknown",
        batteryLevel: (json["batteryLevel"] ?? 0) as int,
        batteryTempC: (json["batteryTempC"] ?? 0.0).toDouble(),
        batteryHealth: json["batteryHealth"] ?? "Unknown",
        stepsSinceBoot: json["stepsSinceBoot"],
        activity: json["activity"],
        wifiSsid: json["wifiSsid"],
        wifiRssi: json["wifiRssi"],
        localIp: json["localIp"],
        carrierName: json["carrierName"],
        cellularDbm: json["cellularDbm"],
        simState: json["simState"],
        timestamp: DateTime.tryParse(json["timestamp"] ?? "") ?? DateTime.now(),
      );
}
