class Peer {
  final String serviceName;
  final String host;
  final int port;

  final String? deviceName;
  final String? model; 

  const Peer({
    required this.serviceName,
    required this.host,
    required this.port,
    this.deviceName,
    this.model,
  });

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      serviceName: (json['serviceName'] ?? '').toString(),
      host: (json['host'] ?? '').toString(),
      port: _asInt(json['port'], fallback: 0),
      deviceName: _asNullableString(json['deviceName']),
      model: _asNullableString(json['model']),
    );
  }

  Map<String, dynamic> toJson() => {
        "serviceName": serviceName,
        "host": host,
        "port": port,
        "deviceName": deviceName,
        "model": model,
      };

  String get endpoint => "$host:$port";

  @override
  String toString() => "Peer($serviceName @ $endpoint)";
}

int _asInt(dynamic v, {required int fallback}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
