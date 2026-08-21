import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/repeater_command_drawer.dart';
import '../helpers/snack_bar_builder.dart';

/// Dev-only preview: renders a static, non-functional stand-in for the
/// repeater CLI terminal so [RepeaterCommandDrawer] can be reviewed in its
/// real visual context (terminal above, drawer below) without a live
/// BLE/TCP/USB connection. Reachable from App Settings > App Debug Log.
class RepeaterCommandDrawerPreviewScreen extends StatelessWidget {
  const RepeaterCommandDrawerPreviewScreen({super.key});

  static const _fakeLines = [
    (isCommand: true, text: 'ver'),
    (isCommand: false, text: '-> v1.17.0 (9 Aug 2026)'),
    (isCommand: true, text: 'net status'),
    (
      isCommand: false,
      text:
          '-> wifi:connected ip:192.168.40.21 rssi:-58dBm mqtt:down '
          'ntp:synced',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg1,
        title: Text(context.l10n.debugLog_previewCommandDrawer),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: context.l10n.debugLog_previewCommandDrawer,
            onPressed: () => RepeaterCommandDrawer.show(
              context,
              onCommandSelected: (command) {
                showDismissibleSnackBar(context, content: Text(command));
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(t.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in _fakeLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        line.isCommand ? '>' : ' ',
                        style: t
                            .monoCaption(
                              color: line.isCommand ? t.primary : t.ink3,
                            )
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: t.spacingXs),
                    Expanded(
                      child: Text(
                        line.text,
                        style: t.monoBody(
                          color: line.isCommand ? t.primary : t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '>',
                    style: t
                        .monoCaption(color: t.primary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: t.spacingXs),
                Container(width: 8, height: 15, color: t.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
