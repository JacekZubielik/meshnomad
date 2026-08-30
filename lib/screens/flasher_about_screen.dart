import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';

/// Flasher-specific info screen, reachable from the Flasher's ⋮ menu.
/// Reuses the same strings already shown elsewhere in the flashing flow
/// (`flasherBootHint`, `flasherFullResetOption`, `flasherUpdateOption`)
/// rather than restating them differently here.
class FlasherAboutScreen extends StatelessWidget {
  const FlasherAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        // Circular/accent app-bar family (2026-08-29) — see
        // docs/superpowers/meshnomad-vault/templates/ui-patterns/app-bar-schema.md.
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(l10n.flasherAboutMenuItem),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.flasherAboutIntro),
            SizedBox(height: t.spacingMd),
            Text(
              l10n.flasherAboutFullResetHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: t.spacingXxs),
            Text(l10n.flasherFullResetOption),
            SizedBox(height: t.spacingMd),
            Text(
              l10n.flasherAboutUpdateHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: t.spacingXxs),
            Text(l10n.flasherUpdateOption),
            SizedBox(height: t.spacingMd),
            Text(
              l10n.flasherAboutConnectionHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: t.spacingXxs),
            Text(l10n.flasherBootHint),
          ],
        ),
      ),
    );
  }
}
