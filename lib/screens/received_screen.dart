import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/device_snapshot.dart';
import '../storage/received_store.dart';

class ReceivedScreen extends StatelessWidget {
  const ReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ReceivedStore();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Received Snapshots"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await store.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cleared received history")),
                );
              }
            },
          )
        ],
      ),
      body: ValueListenableBuilder<Box<String>>(
        valueListenable: store.listenable(),
        builder: (context, box, _) {
          final items = box.values.toList().reversed.toList(); // newest first

          if (items.isEmpty) {
            return const Center(
              child: Text("No received snapshots yet.\nOpen Share on another device and send one."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final raw = items[i];
              DeviceSnapshot? snap;

              try {
                final map = jsonDecode(raw) as Map<String, dynamic>;
                snap = DeviceSnapshot.fromJson(map);
              } catch (_) {
                // ignore parse errors (still show raw)
              }

              return Card(
                child: ListTile(
                  title: Text(snap?.deviceName ?? "Unknown Device"),
                  subtitle: Text(
                    [
                      if (snap?.model != null) "Model: ${snap!.model}",
                      if (snap?.batteryLevel != null) "Battery: ${snap!.batteryLevel}%",
                      if (snap?.stepsSinceBoot != null) "Steps: ${snap!.stepsSinceBoot}",
                      if (snap?.activity != null) "Activity: ${snap!.activity}",
                      if (snap?.wifiSsid != null) "Wi-Fi: ${snap!.wifiSsid}",
                      if (snap?.carrierName != null) "Carrier: ${snap!.carrierName}",
                      "Time: ${snap?.timestamp.toLocal().toString() ?? "-"}",
                    ].join(" • "),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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

    return Scaffold(
      appBar: AppBar(title: const Text("Snapshot Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            map != null ? const JsonEncoder.withIndent("  ").convert(map) : rawJson,
            style: const TextStyle(fontFamily: "monospace"),
          ),
        ),
      ),
    );
  }
}
