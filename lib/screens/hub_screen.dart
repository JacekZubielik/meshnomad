import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'flasher_screen.dart';
import 'scanner_screen.dart';
import 'usb_screen.dart';

/// App entry point (replaces `ScannerScreen` as `main.dart`'s `home:`).
/// Three tiles route to the existing companion-connect flow (unchanged),
/// the new Flasher, and the v1 Setup USB placeholder (routes to the
/// existing [UsbScreen] companion USB-connect flow — full repeater/room
/// server setup over USB is a later iteration).
class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('MeshNomad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HubTile(
              icon: Icons.podcasts,
              title: l10n.hubCompanionTile,
              subtitle: l10n.hubCompanionSubtitle,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScannerScreen())),
            ),
            const SizedBox(height: 12),
            _HubTile(
              icon: Icons.bolt,
              title: l10n.hubFlasherTile,
              subtitle: l10n.hubFlasherSubtitle,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FlasherScreen())),
            ),
            const SizedBox(height: 12),
            _HubTile(
              icon: Icons.build,
              title: l10n.hubSetupTile,
              subtitle: l10n.hubSetupSubtitle,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UsbScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
