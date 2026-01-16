import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/device_snapshot.dart';
import '../storage/received_store.dart';
import '../widgets/time_converter.dart';
import '../widgets/snap_details_converter.dart';

class ReceivedScreen extends StatelessWidget {
  const ReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ReceivedStore();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Received Snapshots"),
        actions: [
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
      body: ValueListenableBuilder<Box<String>>(
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

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final raw = items[i];

              DeviceSnapshot? snap;
              try {
                final map = jsonDecode(raw) as Map<String, dynamic>;
                snap = DeviceSnapshot.fromJson(map);
              } catch (_) {}

              final title = snap?.deviceName ?? "Unknown Device";

              final summary = [
                if (snap?.model != null) "📱 ${snap!.model}",
                if (snap != null) "🔋 ${snap.batteryLevel}%",
                if (snap?.stepsSinceBoot != null) "👣 ${snap!.stepsSinceBoot}",
                if (snap?.activity != null) "🏃 ${snap!.activity}",
                if (snap?.wifiSsid != null) "📶 ${snap!.wifiSsid}",
                if (snap?.carrierName != null) "📡 ${snap!.carrierName}",
              ].join("  ");

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ReceivedDetailScreen(rawJson: raw),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.inbox_outlined),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summary.isEmpty
                                    ? "Tap to view details"
                                    : summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color:
                                          cs.onSurface,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TimeConverter(dateTime: snap?.timestamp),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
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
    DeviceSnapshot? snap;

    try {
      map = jsonDecode(rawJson) as Map<String, dynamic>;
      snap = DeviceSnapshot.fromJson(map);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: const Text("Snapshot Details"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "View raw JSON",
            icon: const Icon(Icons.code),
            onPressed: () {
              final pretty = map != null
                  ? const JsonEncoder.withIndent("  ").convert(map)
                  : rawJson;

              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      pretty,
                      style: const TextStyle(fontFamily: "monospace"),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: snap == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Couldn’t parse this snapshot 😵‍💫\nTry sending again.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : SnapDetailsConverter(snap: snap),
    );
  }
}
