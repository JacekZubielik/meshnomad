import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/mesh_ui.dart';

Future<void> pushAboutScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
  );
}

/// App version and attribution — its own screen, matching the App Settings
/// navigation pattern (2026-08-22 unification; used to be Flutter's built-in
/// `showAboutDialog` popup).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_about), centerTitle: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(t.spacingMd),
          children: [
            MeshCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: t.spacingXxs),
                  Text(
                    l10n.settings_aboutVersion(
                      _appVersion.isEmpty ? l10n.common_loading : _appVersion,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: t.spacingMd),
                  Text(l10n.settings_aboutDescription),
                  SizedBox(height: t.spacingMd),
                  Text(
                    l10n.settings_aboutLegalese,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
