import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/app_debug_log_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/adaptive_app_bar_title.dart';
import '../widgets/app_bar.dart';
import '../helpers/snack_bar_builder.dart';
import 'repeater_command_drawer_preview_screen.dart';

class AppDebugLogScreen extends StatelessWidget {
  const AppDebugLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    return Consumer<AppDebugLogService>(
      builder: (context, logService, _) {
        final entries = logService.entries.reversed.toList();
        final hasEntries = entries.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: AdaptiveAppBarTitle(context.l10n.debugLog_appTitle),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: context.l10n.debugLog_copyLog,
                icon: const Icon(Icons.copy),
                onPressed: hasEntries
                    ? () async {
                        final text = entries
                            .map(
                              (entry) =>
                                  '[${entry.formattedTime}] [${entry.levelLabel}] [${entry.tag}] ${entry.message}',
                            )
                            .join('\n');
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        showDismissibleSnackBar(
                          context,
                          content: Text(context.l10n.debugLog_copied),
                        );
                      }
                    : null,
              ),
              IconButton(
                tooltip: context.l10n.debugLog_clearLog,
                icon: const Icon(Icons.delete_outline),
                onPressed: hasEntries
                    ? () {
                        logService.clear();
                      }
                    : null,
              ),
              IconButton(
                tooltip: context.l10n.debugLog_previewCommandDrawer,
                icon: const Icon(Icons.terminal),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RepeaterCommandDrawerPreviewScreen(),
                  ),
                ),
              ),
              const QuickAccessMenuButton(),
            ],
          ),
          body: SafeArea(
            top: false,
            child: hasEntries
                ? ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: MeshTokens.of(context).line),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        color: MeshTokens.of(context).bg,
                        padding: EdgeInsets.symmetric(
                          horizontal: MeshTokens.of(context).spacingMd,
                          vertical: MeshTokens.of(context).spacingXs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLevelIcon(context, entry.level),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '[${entry.tag}] ',
                                          style: MeshTokens.of(context)
                                              .monoCaption(
                                                color: _levelColor(
                                                  context,
                                                  entry.level,
                                                ),
                                              ),
                                        ),
                                        TextSpan(
                                          text: entry.message,
                                          style: MeshTokens.of(context)
                                              .monoCaption(
                                                color: MeshTokens.of(
                                                  context,
                                                ).ink2,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    entry.formattedTime,
                                    style: MeshTokens.of(context).monoCaption(
                                      color: MeshTokens.of(context).ink4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bug_report_outlined,
                          size: 64,
                          color: MeshTokens.of(context).ink3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.debugLog_noEntries,
                          style: TextStyle(
                            fontSize: 16,
                            color: MeshTokens.of(context).ink3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.debugLog_enableInSettings,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: MeshTokens.of(context).ink3),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Color _levelColor(BuildContext context, AppDebugLogLevel level) {
    switch (level) {
      case AppDebugLogLevel.info:
        return MeshTokens.of(context).primary;
      case AppDebugLogLevel.warning:
        return MeshTokens.of(context).warn;
      case AppDebugLogLevel.error:
        return MeshTokens.of(context).alert;
    }
  }

  Widget _buildLevelIcon(BuildContext context, AppDebugLogLevel level) {
    switch (level) {
      case AppDebugLogLevel.info:
        return Icon(
          Icons.info_outline,
          size: 18,
          color: MeshTokens.of(context).primary,
        );
      case AppDebugLogLevel.warning:
        return Icon(
          Icons.warning_amber_outlined,
          size: 18,
          color: MeshTokens.of(context).warn,
        );
      case AppDebugLogLevel.error:
        return Icon(
          Icons.error_outline,
          size: 18,
          color: MeshTokens.of(context).alert,
        );
    }
  }
}
