import 'package:flutter/material.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/app_localizations.dart';
import '../theme/mesh_tokens.dart';

/// A drop-down overlay that floats directly below the search field (or
/// directly below the app bar on screens with none) — it always sits ON TOP
/// of list/map content, never pushes it down. Positioned by the caller
/// (a `Stack`); this widget only owns its own open/close animation and
/// chrome.
///
/// Generic on purpose: [child] is `null` when there's nothing to show and
/// any [Widget] otherwise. Today only [WindaProgress] is ever passed in —
/// a future message-mode widget (icon + text, replacing
/// `showDismissibleSnackBar`) slots into the exact same shell later without
/// changing this class.
class WindaOverlay extends StatelessWidget {
  final Widget? child;

  const WindaOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: child == null
            ? const SizedBox(width: double.infinity)
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey(child.runtimeType),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
      ),
    );
  }
}

/// Progress content for [WindaOverlay] — the pill-track visual matches
/// `_pillTrack()` in flasher_version_row.dart:162-183. One color (primary)
/// for every operation; [label] is what tells them apart, not color.
class WindaProgress extends StatelessWidget {
  final String label;

  /// `null` = indeterminate (sliding-thumb pill, no percentage shown).
  /// Otherwise a value in `[0.0, 1.0]`.
  final double? value;

  const WindaProgress({super.key, required this.label, this.value});

  /// Priority order matches the mechanism this replaces: contacts, then
  /// channels, then queued messages. Returns `null` when nothing is syncing.
  static WindaProgress? fromConnector(
    MeshCoreConnector connector,
    AppLocalizations l10n,
  ) {
    if (connector.isLoadingContacts) {
      return WindaProgress(
        label: l10n.common_syncingContacts,
        value: connector.contactSyncProgress,
      );
    }
    if (connector.isSyncingChannels) {
      return WindaProgress(
        label: l10n.common_syncingChannels,
        value: connector.channelSyncProgress / 100,
      );
    }
    if (connector.isShowingQueuedMessageSyncProgress) {
      return WindaProgress(
        label: l10n.common_sendingQueuedMessages,
        value: null,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacingXs,
        t.spacingSm,
        t.spacingXs,
        t.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.ink3),
          ),
          SizedBox(height: t.spacingXxs),
          Row(
            children: [
              Expanded(child: _PillTrack(value: value)),
              if (value != null) ...[
                SizedBox(width: t.spacingSm),
                Text(
                  '${(value! * 100).round()}%',
                  style: t.monoBody(color: t.primary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The pill track: a determinate left-anchored fill when [value] is
/// non-null, or a fixed centered thumb when [value] is `null`
/// (indeterminate — no motion).
///
/// Deliberately static rather than animated: a repeating [AnimationController]
/// (or any self-perpetuating animation, including a [TweenAnimationBuilder]
/// that re-triggers itself from `onEnd`) keeps scheduling frames forever and
/// makes `tester.pumpAndSettle()` throw ("pumpAndSettle timed out") — a
/// well-known Flutter testing pitfall shared with the built-in indeterminate
/// `LinearProgressIndicator`. A static thumb still communicates "something is
/// happening, no known duration" without fighting the test harness; a
/// looping variant can be revisited later behind an explicit opt-out for
/// tests if the animation is ever wanted.
class _PillTrack extends StatelessWidget {
  final double? value;

  const _PillTrack({required this.value});

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.2),
        border: Border.all(color: t.primary),
        borderRadius: BorderRadius.circular(t.pill),
      ),
      child: value != null
          ? FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value!.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(t.pill),
                ),
              ),
            )
          : Align(
              child: FractionallySizedBox(
                widthFactor: 0.3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(t.pill),
                  ),
                ),
              ),
            ),
    );
  }
}
