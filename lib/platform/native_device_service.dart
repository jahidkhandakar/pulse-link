import 'package:flutter/services.dart';
import '../models/device_snapshot.dart';

class NativeDeviceService {
  static const _channel = MethodChannel('com.pulselink/native');

  Future<Map<String, dynamic>> _getMap(String method) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(method);
    return (res ?? {}).map((k, v) => MapEntry(k.toString(), v));
  }

  Future<DeviceSnapshot> getSnapshot() async {
    final data = await _getMap('getSnapshot');
    return DeviceSnapshot.fromJson(data);
  }
}
