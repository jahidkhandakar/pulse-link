import 'package:flutter/services.dart';
import '../models/device_snapshot.dart';

class NativeDeviceService {
  static const _channel = MethodChannel('com.pulselink/native');

  Future<bool> hasWifiPermissions() async =>
      (await _channel.invokeMethod<bool>('hasWifiPermissions')) ?? false;

  Future<bool> requestWifiPermissions() async =>
      (await _channel.invokeMethod<bool>('requestWifiPermissions')) ?? false;

  Future<bool> hasPhonePermissions() async =>
      (await _channel.invokeMethod<bool>('hasPhonePermissions')) ?? false;

  Future<bool> requestPhonePermissions() async =>
      (await _channel.invokeMethod<bool>('requestPhonePermissions')) ?? false;

  Future<Map<String, dynamic>> _getMap(String method) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(method);
    return (res ?? {}).map((k, v) => MapEntry(k.toString(), v));
  }

  Future<DeviceSnapshot> getSnapshot() async {
    final data = await _getMap('getSnapshot');
    return DeviceSnapshot.fromJson(data);
  }
}
