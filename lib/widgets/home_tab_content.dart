import 'package:flutter/material.dart';

import '../models/device_snapshot.dart';
import 'metric_card.dart';
import 'notice_board.dart';
import 'section_container.dart';

class HomeTabContent extends StatelessWidget {
  final DeviceSnapshot? snap;
  final String? error;

  final Future<void> Function() onRefresh;
  final Future<void> Function() onRequestWifi;
  final Future<void> Function() onRequestPhone;

  const HomeTabContent({
    super.key,
    required this.snap,
    required this.error,
    required this.onRefresh,
    required this.onRequestWifi,
    required this.onRequestPhone,
  });

  @override
  Widget build(BuildContext context) {
    final s = snap;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) _errorBanner(context, error!),

          // Section: Device + Battery (row)
          SectionContainer(
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: "Device",
                      lines: [
                        "Name: ${s?.deviceName ?? '-'}",
                        "Model: ${s?.model ?? '-'}",
                        "Android: ${s?.androidVersion ?? '-'}",
                        "Local IP: ${s?.localIp ?? '-'}",
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: "Battery",
                      lines: [
                        "Level: ${s?.batteryLevel ?? '-'}%",
                        "Temp: ${s?.batteryTempC.toStringAsFixed(1) ?? '-'}°C",
                        "Health: ${s?.batteryHealth ?? '-'}",
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section: Steps + Activity (row)
          SectionContainer(
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: "Steps",
                      lines: ["Since boot: ${s?.stepsSinceBoot ?? '-'}"],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: "Activity",
                      lines: ["Detected: ${s?.activity ?? '-'}"],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section: Wi-Fi + button
          SectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricCard(
                  title: "Wi-Fi",
                  lines: [
                    "SSID: ${s?.wifiSsid ?? '-'}",
                    "RSSI: ${s?.wifiRssi ?? '-'} dBm",
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onRequestWifi,
                  icon: const Icon(Icons.wifi),
                  label: const Text("Enable Wi-Fi Data Access"),
                ),
              ],
            ),
          ),

          // Section: Cellular + button
          SectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricCard(
                  title: "Cellular",
                  lines: [
                    "Carrier: ${s?.carrierName ?? '-'}",
                    "SIM: ${s?.simState ?? '-'}",
                    "Signal: ${s?.cellularDbm ?? '-'} dBm",
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onRequestPhone,
                  icon: const Icon(Icons.cell_tower),
                  label: const Text("Enable Carrier & Signal Data"),
                ),
              ],
            ),
          ),

          // Notice board
          NoticeBoard(
            text:
                "NB: If some fields show '-', it usually means permissions are missing or the device/OEM restricts access.",
          ),

          const SizedBox(height: 90), // breathing room above bottom nav
        ],
      ),
    );
  }

  Widget _errorBanner(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
