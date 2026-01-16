import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_snapshot.dart';
import '../models/peer.dart';
import '../platform/native_device_service.dart';
import '../platform/native_network_service.dart';
import '../widgets/peer_details_converter.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _device = NativeDeviceService();
  final _net = NativeNetworkService();

  List<Peer> _peers = [];
  StreamSubscription<List<Peer>>? _peerSub;

  bool _starting = true;
  bool _sending = false;

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

    final once = await _net.getPeersOnce();
    if (!mounted) return;
    setState(() {
      _peers = once;
      _starting = false;
    });
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    super.dispose();
  }

  Future<void> _send(Peer peer) async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final DeviceSnapshot snap = await _device.getSnapshot();
      final ok = await _net.sendSnapshotToPeer(
        serviceName: peer.serviceName,
        snapshotJson: snap.toJson(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? "Sent ✅"
                : "Send failed ❌",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Send error: $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _peers.isEmpty
        ? "Searching for peers…\nMake sure both devices are on the same Wi-Fi and the app is open."
        : "Found ${_peers.length} peer(s). Tap one to send your snapshot.";

    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Peers"), centerTitle: true,),
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
                        child: Text(header),
                      ),
                    );
                  }

                  final peer = _peers[i - 1];

                  return Card(
                    child: InkWell(
                      onTap: _sending ? null : () => _send(peer),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: PeerDetailsConverter(
                          peer: peer,
                          trailing: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
