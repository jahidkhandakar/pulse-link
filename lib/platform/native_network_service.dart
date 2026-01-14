import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/peer.dart';

class NativeNetworkService {
  static const MethodChannel _method = MethodChannel('com.pulselink/native');
  static const EventChannel _receivedEvents =
      EventChannel('com.pulselink/events/received');
  static const EventChannel _peersEvents =
      EventChannel('com.pulselink/events/peers');

  bool _started = false;

  // Cache streams so multiple listeners don't create multiple platform streams.
  Stream<String>? _receivedStream;
  Stream<List<Peer>>? _peersStream;

  Stream<String> get receivedJsonStream {
    _receivedStream ??= _receivedEvents
        .receiveBroadcastStream()
        .map((e) => e as String)
        .handleError((_) {});
    return _receivedStream!;
  }

  Stream<List<Peer>> get peersStream {
    _peersStream ??= _peersEvents
        .receiveBroadcastStream()
        .map((e) => (e as List)
            .map((x) => Peer.fromJson(Map<String, dynamic>.from(x)))
            .toList())
        .handleError((_) {});
    return _peersStream!;
  }

  Future<void> startNetworking() async {
    if (_started) return;
    _started = true;

    try {
      // small timeout so UI doesn't hang forever if platform side errors
      await _method.invokeMethod('startNetworking').timeout(
            const Duration(seconds: 5),
          );
    } catch (_) {
      // If start failed, allow retry later
      _started = false;
      rethrow;
    }
  }

  Future<void> stopNetworking() async {
    _started = false;
    try {
      await _method.invokeMethod('stopNetworking').timeout(
            const Duration(seconds: 5),
          );
    } catch (_) {
      // ignore
    }
  }

  Future<List<Peer>> getPeersOnce() async {
    try {
      final res = await _method
          .invokeMethod<List>('getPeers')
          .timeout(const Duration(seconds: 5));

      return (res ?? [])
          .map((x) => Peer.fromJson(Map<String, dynamic>.from(x)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> sendSnapshotToPeer({
    required String serviceName,
    required Map<String, dynamic> snapshotJson,
  }) async {
    try {
      final ok = await _method.invokeMethod<bool>(
        'sendSnapshotToPeer',
        {
          'serviceName': serviceName,
          'payloadJson': jsonEncode(snapshotJson),
        },
      ).timeout(const Duration(seconds: 5));

      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
