import 'package:flutter/material.dart';
import 'package:pulse_link/widgets/notice_board.dart';

class StatusDrawer extends StatelessWidget {
  final bool wifiOk;
  final bool phoneOk;
  final bool networkingOn;

  const StatusDrawer({
    super.key,
    required this.wifiOk,
    required this.phoneOk,
    required this.networkingOn,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Status",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            _statusTile(
              context,
              label: "Wi-Fi Permissions",
              ok: wifiOk,
              iconOk: Icons.check_circle,
              iconBad: Icons.error_outline,
            ),
            _statusTile(
              context,
              label: "Phone Permissions",
              ok: phoneOk,
              iconOk: Icons.check_circle,
              iconBad: Icons.error_outline,
            ),
            _statusTile(
              context,
              label: "Networking",
              ok: networkingOn,
              iconOk: Icons.cloud_done,
              iconBad: Icons.cloud_off,
              okText: "ON",
              badText: "OFF",
            ),

            const SizedBox(height: 350),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),

            Text(
              "Tip",
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            NoticeBoard(
              text:
                  "If some fields show '-', it usually means permissions are missing or the Device/OEM restricts access.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(
    BuildContext context, {
    required String label,
    required bool ok,
    required IconData iconOk,
    required IconData iconBad,
    String okText = "OK",
    String badText = "NO",
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(ok ? iconOk : iconBad),
        title: Text(label),
        trailing: Text(
          ok ? okText : badText,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: ok ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
