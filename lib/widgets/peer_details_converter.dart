import 'package:flutter/material.dart';
import '../models/peer.dart';

class PeerDetailsConverter extends StatelessWidget {
  final Peer peer;
  final Widget? trailing;

  const PeerDetailsConverter({
    super.key,
    required this.peer,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = (peer.deviceName?.trim().isNotEmpty ?? false)
        ? peer.deviceName!.trim()
        : peer.serviceName;

    final model = (peer.model?.trim().isNotEmpty ?? false)
        ? peer.model!.trim()
        : null;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          foregroundColor: cs.onSurface,
          child: const Icon(Icons.phone_android),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (model != null) model,
                  peer.endpoint,
                ].join(" • "),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
