class Peer {
  final String serviceName;
  final String host;
  final int port;

  Peer({required this.serviceName, required this.host, required this.port});

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
        serviceName: json['serviceName'],
        host: json['host'],
        port: json['port'],
      );
}
