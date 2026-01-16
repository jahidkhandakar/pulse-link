import 'package:flutter/material.dart';
import '../models/device_snapshot.dart';
import 'section_container.dart';
import 'metric_card.dart';
import 'time_converter.dart';

class SnapDetailsConverter extends StatelessWidget {
  final DeviceSnapshot snap;

  const SnapDetailsConverter({super.key, required this.snap});

  @override
  Widget build(BuildContext context) {
    final s = snap;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(context),
        const SizedBox(height: 12),

        SectionContainer(
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: "Device",
                    lines: [
                      "Name: ${s.deviceName}",
                      "Model: ${s.model}",
                      "Android: ${s.androidVersion}",
                      "IP: ${s.localIp ?? '-'}",
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: "Battery",
                    lines: [
                      "Level: ${s.batteryLevel}%",
                      "Temp: ${s.batteryTempC.toStringAsFixed(1)}°C",
                      "Health: ${s.batteryHealth}",
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SectionContainer(
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: "Steps",
                    lines: [
                      "Since boot: ${s.stepsSinceBoot ?? '-'}",
                      if (s.stepSensorAvailable == false) "Sensor: Not supported",
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: "Activity",
                    lines: ["Detected: ${s.activity ?? '-'}"],
                  ),
                ),
              ],
            ),
          ),
        ),

        SectionContainer(
          child: MetricCard(
            title: "Wi-Fi",
            lines: [
              "SSID: ${s.wifiSsid ?? '-'}",
              "RSSI: ${s.wifiRssi ?? '-'} dBm",
            ],
          ),
        ),

        SectionContainer(
          child: MetricCard(
            title: "Cellular",
            lines: [
              "Carrier: ${s.carrierName ?? '-'}",
              "SIM: ${s.simState ?? '-'}",
              "Signal: ${s.cellularDbm ?? '-'} dBm",
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snap.titleLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Snapshot received",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          TimeConverter(dateTime: snap.timestamp),
        ],
      ),
    );
  }
}
