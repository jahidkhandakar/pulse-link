import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/peer.dart';

class NativeNetworkService {
  static const _method = MethodChannel('com.pulselink/native');
  static const _receivedEvents = EventChannel('com.pulselink/events/received');
  static const _peersEvents = EventChannel('com.pulselink/events/peers');

  Stream<String> get receivedJsonStream =>
      _receivedEvents.receiveBroadcastStream().map((e) => e as String);

  Stream<List<Peer>> get peersStream => _peersEvents
      .receiveBroadcastStream()
      .map((e) => (e as List)
          .map((x) => Peer.fromJson(Map<String, dynamic>.from(x)))
          .toList());

  Future<void> startNetworking() async {
    await _method.invokeMethod('startNetworking');
  }

  Future<void> stopNetworking() async {
    await _method.invokeMethod('stopNetworking');
  }

  Future<List<Peer>> getPeersOnce() async {
    final res = await _method.invokeMethod<List>('getPeers');
    final list = (res ?? [])
        .map((x) => Peer.fromJson(Map<String, dynamic>.from(x)))
        .toList();
    return list;
  }

  Future<bool> sendSnapshotToPeer({
    required String serviceName,
    required Map<String, dynamic> snapshotJson,
  }) async {
    final ok = await _method.invokeMethod<bool>('sendSnapshotToPeer', {
      'serviceName': serviceName,
      'payloadJson': jsonEncode(snapshotJson),
    });
    return ok ?? false;
  }
}
