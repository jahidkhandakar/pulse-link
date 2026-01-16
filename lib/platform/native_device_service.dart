import 'package:flutter/services.dart';
import '../models/device_snapshot.dart';

class NativeDeviceService {
  static const _channel = MethodChannel('com.pulselink/native');

  // ---------- Snapshot ----------
  Future<Map<String, dynamic>> _getMap(String method) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(method);
    return (res ?? {}).map((k, v) => MapEntry(k.toString(), v));
  }

  Future<DeviceSnapshot> getSnapshot() async {
    final data = await _getMap('getSnapshot');
    return DeviceSnapshot.fromJson(data);
  }

  // ---------- Wi-Fi permissions ----------
  Future<bool> hasWifiPermissions() async =>
      (await _channel.invokeMethod<bool>('hasWifiPermissions')) ?? false;

  Future<bool> requestWifiPermissions() async =>
      (await _channel.invokeMethod<bool>('requestWifiPermissions')) ?? false;

  // ---------- Phone permissions ----------
  Future<bool> hasPhonePermissions() async =>
      (await _channel.invokeMethod<bool>('hasPhonePermissions')) ?? false;

  Future<bool> requestPhonePermissions() async =>
      (await _channel.invokeMethod<bool>('requestPhonePermissions')) ?? false;

  // ---------- Activity Recognition permissions (Android 10+ / API 29+) ----------
  Future<bool> hasActivityPermissions() async =>
      (await _channel.invokeMethod<bool>('hasActivityPermissions')) ?? false;

  Future<bool> requestActivityPermissions() async =>
      (await _channel.invokeMethod<bool>('requestActivityPermissions')) ?? false;
}
