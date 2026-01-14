class Peer {
  final String serviceName;
  final String host;
  final int port;

  const Peer({
    required this.serviceName,
    required this.host,
    required this.port,
  });

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      serviceName: (json['serviceName'] ?? '').toString(),
      host: (json['host'] ?? '').toString(),
      port: _asInt(json['port'], fallback: 0),
    );
  }

  Map<String, dynamic> toJson() => {
        "serviceName": serviceName,
        "host": host,
        "port": port,
      };

  String get endpoint => "$host:$port";

  @override
  String toString() => "Peer($serviceName @ $endpoint)";
}

int _asInt(dynamic v, {required int fallback}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}
