import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_snapshot.dart';
import '../models/peer.dart';
import '../platform/native_device_service.dart';
import '../platform/native_network_service.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _device = NativeDeviceService();
  final _net = NativeNetworkService();

  List<Peer> _peers = [];
  StreamSubscription? _peerSub;

  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _net.startNetworking();

    _peerSub = _net.peersStream.listen((list) {
      if (!mounted) return;
      setState(() {
        _peers = list;
        _starting = false;
      });
    });

    // quick initial pull
    final once = await _net.getPeersOnce();
    if (mounted) setState(() => _peers = once);
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    super.dispose();
  }

  Future<void> _send(Peer peer) async {
    final DeviceSnapshot snap = await _device.getSnapshot();
    final ok = await _net.sendSnapshotToPeer(
      serviceName: peer.serviceName,
      snapshotJson: snap.toJson(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Sent to ${peer.serviceName} ✅" : "Send failed ❌")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Peers")),
      body: _starting && _peers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final once = await _net.getPeersOnce();
                if (mounted) setState(() => _peers = once);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _peers.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _peers.isEmpty
                              ? "No peers found yet. Make sure both devices are on the same Wi-Fi and the app is open."
                              : "Tap a peer to send your current snapshot.",
                        ),
                      ),
                    );
                  }
                  final peer = _peers[i - 1];
                  return Card(
                    child: ListTile(
                      title: Text(peer.serviceName),
                      subtitle: Text("${peer.host}:${peer.port}"),
                      trailing: const Icon(Icons.send),
                      onTap: () => _send(peer),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
