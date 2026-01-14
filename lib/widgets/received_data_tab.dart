import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/device_snapshot.dart';
import '../storage/received_store.dart';
import 'section_container.dart';

class ReceivedDataTab extends StatelessWidget {
  const ReceivedDataTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ReceivedStore();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SectionContainer(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Received Snapshots",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: "Clear history",
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await store.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cleared received history")),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<Box<String>>(
              valueListenable: store.listenable(),
              builder: (context, box, _) {
                final items = box.values.toList().reversed.toList();

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      "No received snapshots yet.\nOpen Share on another device and send one.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final raw = items[i];

                    DeviceSnapshot? snap;
                    try {
                      final map = jsonDecode(raw) as Map<String, dynamic>;
                      snap = DeviceSnapshot.fromJson(map);
                    } catch (_) {}

                    final title = snap?.deviceName ?? "Unknown Device";
                    final time = snap?.timestamp.toLocal().toString().split('.').first ?? "-";

                    final summary = [
                      if (snap?.batteryLevel != null) "🔋 ${snap!.batteryLevel}%",
                      if (snap?.activity != null) "🏃 ${snap!.activity}",
                      if (snap?.wifiSsid != null) "📶 ${snap!.wifiSsid}",
                      if (snap?.carrierName != null) "📡 ${snap!.carrierName}",
                    ].join("  ");

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text(
                          summary.isEmpty ? "Tap to view JSON" : summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          time,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ReceivedDetailScreen(rawJson: raw),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedDetailScreen extends StatelessWidget {
  final String rawJson;
  const _ReceivedDetailScreen({required this.rawJson});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? map;
    try {
      map = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {}

    final pretty = map != null
        ? const JsonEncoder.withIndent("  ").convert(map)
        : rawJson;

    return Scaffold(
      appBar: AppBar(title: const Text("Snapshot Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            pretty,
            style: const TextStyle(fontFamily: "monospace"),
          ),
        ),
      ),
    );
  }
}
