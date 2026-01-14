import 'dart:async';
import 'package:flutter/material.dart';

import '../models/device_snapshot.dart';
import '../platform/native_device_service.dart';
import '../platform/native_network_service.dart';
import '../storage/received_store.dart';
import 'received_screen.dart';
import 'share_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _net = NativeNetworkService();
  final _store = ReceivedStore();
  final _device = NativeDeviceService();

  StreamSubscription<String>? _rxSub;
  Timer? _timer;

  bool _networkBooted = false;
  bool _wifiPermOk = false;
  bool _phonePermOk = false;

  DeviceSnapshot? _snap;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _refresh(); // initial snapshot fast
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());

    await _checkPerms();
    await _bootNetworkingOnce();
  }

  Future<void> _checkPerms() async {
    try {
      final wifi = await _device.hasWifiPermissions();
      final phone = await _device.hasPhonePermissions();
      if (!mounted) return;
      setState(() {
        _wifiPermOk = wifi;
        _phonePermOk = phone;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _bootNetworkingOnce() async {
    if (_networkBooted) return;
    _networkBooted = true;

    try {
      await _net.startNetworking();

      _rxSub = _net.receivedJsonStream.listen((jsonStr) async {
        try {
          await _store.addRaw(jsonStr);
        } catch (_) {
          // ignore
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Networking error: $e");
    }
  }

  Future<void> _refresh() async {
    try {
      final s = await _device.getSnapshot();
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

  Future<void> _requestWifiPerm() async {
    final ok = await _device.requestWifiPermissions();
    if (!mounted) return;

    setState(() => _wifiPermOk = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Wi-Fi permissions granted ✅" : "Wi-Fi permission denied ❌")),
    );
    await _refresh();
  }

  Future<void> _requestPhonePerm() async {
    final ok = await _device.requestPhonePermissions();
    if (!mounted) return;

    setState(() => _phonePermOk = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Phone permission granted ✅" : "Phone permission denied ❌")),
    );
    await _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rxSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _snap;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PulseLink'),
        actions: [
          IconButton(
            tooltip: "Received Data",
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReceivedScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkPerms();
          await _refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) _errorBanner(_error!),

            _permChips(),

            _card("Device", [
              "Name: ${s?.deviceName ?? '-'}",
              "Model: ${s?.model ?? '-'}",
              "Android: ${s?.androidVersion ?? '-'}",
              "Local IP: ${s?.localIp ?? '-'}",
            ]),

            _card("Battery", [
              "Level: ${s?.batteryLevel ?? '-'}%",
              "Temp: ${s?.batteryTempC.toStringAsFixed(1) ?? '-'}°C",
              "Health: ${s?.batteryHealth ?? '-'}",
            ]),

            _card("Steps", [
              "Steps since boot: ${s?.stepsSinceBoot ?? '-'}",
            ]),

            _card("Activity", [
              "Detected: ${s?.activity ?? '-'}",
            ]),

            _card("Wi-Fi", [
              "SSID: ${s?.wifiSsid ?? '-'}",
              "RSSI: ${s?.wifiRssi ?? '-'} dBm",
            ]),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _requestWifiPerm,
              icon: const Icon(Icons.wifi),
              label: const Text("Enable Wi-Fi Data Access"),
            ),

            const SizedBox(height: 12),

            _card("Cellular", [
              "Carrier: ${s?.carrierName ?? '-'}",
              "SIM: ${s?.simState ?? '-'}",
              "Signal: ${s?.cellularDbm ?? '-'} dBm",
            ]),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _requestPhonePerm,
              icon: const Icon(Icons.cell_tower),
              label: const Text("Enable Carrier & Signal Data"),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShareScreen()),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text("Share My Pulse"),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReceivedScreen()),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text("Received Data"),
            ),

            const SizedBox(height: 14),
            const Text(
              "If some fields show '-', it usually means permissions are missing or the device/OEM restricts access.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(_wifiPermOk ? Icons.check_circle : Icons.error_outline),
          label: Text("Wi-Fi: ${_wifiPermOk ? "OK" : "NO"}"),
        ),
        Chip(
          avatar: Icon(_phonePermOk ? Icons.check_circle : Icons.error_outline),
          label: Text("Phone: ${_phonePermOk ? "OK" : "NO"}"),
        ),
        Chip(
          avatar: Icon(_networkBooted ? Icons.check_circle : Icons.hourglass_empty),
          label: Text("Networking: ${_networkBooted ? "ON" : "OFF"}"),
        ),
      ],
    );
  }

  Widget _errorBanner(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

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
