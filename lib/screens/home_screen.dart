import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_snapshot.dart';
import '../platform/native_device_service.dart';
import '../platform/native_network_service.dart';
import '../storage/received_store.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/status_drawer.dart';
import '../widgets/home_tab_content.dart';
import '../widgets/received_data_tab.dart';
import 'share_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const HomeScreen({super.key, this.initialTabIndex = 0});

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
  bool _activityPermOk = false;

  DeviceSnapshot? _snap;
  String? _error;

  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
    _boot();
  }

  Future<void> _boot() async {
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());

    await _checkPerms();
    await _bootNetworkingOnce();
  }

  Future<void> _checkPerms() async {
    try {
      final wifi = await _device.hasWifiPermissions();
      final phone = await _device.hasPhonePermissions();
      final activity = await _device.hasActivityPermissions();

      if (!mounted) return;
      setState(() {
        _wifiPermOk = wifi;
        _phonePermOk = phone;
        _activityPermOk = activity;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _bootNetworkingOnce() async {
    if (_networkBooted) return;

    try {
      await _net.startNetworking();
      _rxSub = _net.receivedJsonStream.listen((jsonStr) async {
        try {
          await _store.addRaw(jsonStr);
        } catch (_) {}
      });

      if (!mounted) return;
      setState(() => _networkBooted = true);
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

  Future<void> _requestActivityPerm() async {
    final ok = await _device.requestActivityPermissions();
    if (!mounted) return;

    setState(() => _activityPermOk = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Activity Recognition enabled ✅" : "Activity Recognition denied ❌")),
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
    return Scaffold(
      appBar: AppAppBar(
        title: 'PulseLink',
        onRefresh: () async {
          await _checkPerms();
          await _refresh();
        },
        onShare: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShareScreen()),
          );
        },
      ),
      drawer: StatusDrawer(
        wifiOk: _wifiPermOk,
        phoneOk: _phonePermOk,
        networkingOn: _networkBooted,
        // if your drawer supports it, you can add activity too later
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeTabContent(
            snap: _snap,
            error: _error,
            onRefresh: () async {
              await _checkPerms();
              await _refresh();
            },
            onRequestWifi: _requestWifiPerm,
            onRequestPhone: _requestPhonePerm,
            onRequestActivity: _requestActivityPerm,
            activityPermOk: _activityPermOk,
          ),
          const ReceivedDataTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Data',
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShareScreen()),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text("Share My Pulse"),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
