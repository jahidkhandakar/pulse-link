import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_snapshot.dart';
import '../platform/native_device_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = NativeDeviceService();
  DeviceSnapshot? _snap;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final s = await _service.getSnapshot();
      if (!mounted) return;
      setState(() {
        _snap = s;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _snap;

    return Scaffold(
      appBar: AppBar(title: const Text('PulseLink')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: () async {
                final ok = await _service.requestWifiPermissions();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? "Wi-Fi permissions granted ✅"
                          : "Permission denied ❌",
                    ),
                  ),
                );
                await _refresh();
              },
              child: const Text("Enable Wi-Fi Data Access"),
            ),
            const SizedBox(height: 12),
            _card("Device", [
              "Name: ${s?.deviceName ?? '-'}",
              "Model: ${s?.model ?? '-'}",
              "Android: ${s?.androidVersion ?? '-'}",
            ]),
            _card("Battery", [
              "Level: ${s?.batteryLevel ?? '-'}%",
              "Temp: ${s?.batteryTempC.toStringAsFixed(1) ?? '-'}°C",
              "Health: ${s?.batteryHealth ?? '-'}",
            ]),
            _card("Steps", ["Steps since boot: ${s?.stepsSinceBoot ?? '-'}"]),
            _card("Wi-Fi", [
              "SSID: ${s?.wifiSsid ?? '-'}",
              "RSSI: ${s?.wifiRssi ?? '-'} dBm",
              "Local IP: ${s?.localIp ?? '-'}",
            ]),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Next feature: open share screen
              },
              child: const Text("Share My Pulse"),
            ),
            const SizedBox(height: 12),
            const Text(
              "More sensors (Steps, Activity, Wi-Fi, Carrier) will appear here next.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  //--------------------Widgets----------------------
  Widget _card(String title, List<String> lines) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...lines.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
