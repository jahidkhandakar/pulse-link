import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final List<String> lines;

  const MetricCard({
    super.key,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ✅ important
        children: [
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
