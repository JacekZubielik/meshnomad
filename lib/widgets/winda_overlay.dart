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
/// No `boxShadow` of its own (removed 2026-09-02) — the "floating above
/// content" drop shadow made sense for the original single-winda design, but
/// once a screen stacks multiple windas (progress card, then a message winda
/// glued below it), an unconditional shadow on every one of them reads as an
/// unwanted line/seam between panels. A caller that wants elevation (e.g.
/// Contacts' search field + progress card) wraps its content in `MeshCard`
/// instead, which gates its shadow behind the app-wide `cardElevated` style
/// toggle — the same mechanism every other card in the app uses.
///
/// Generic on purpose: [child] is `null` when there's nothing to show and
/// any [Widget] otherwise. Today only [WindaProgress] is ever passed in —
/// a future message-mode widget (icon + text, replacing
/// `showDismissibleSnackBar`) slots into the exact same shell later without
/// changing this class.
///
/// Currently wired into Contacts only — see
/// https://github.com/JacekZubielik/meshnomad/issues/143 for wiring it into
/// the other screens that lost sync-progress feedback.
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
                  color: scheme.surface,
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
    if (connector.isLoadingContacts && !connector.contactSyncTimedOut) {
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
      padding: EdgeInsets.fromLTRB(t.spacingXs, 0, t.spacingXs, t.spacingSm),
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
/// non-null, or a sliding thumb loop when [value] is `null` (indeterminate)
/// — per the brief's contract, this must actually slide, not sit static.
///
/// Widget tests covering the indeterminate state must pump fixed durations
/// (`tester.pump(const Duration(...))`) rather than `tester.pumpAndSettle()`
/// — a perpetually-`repeat`ing [AnimationController] never lets
/// `hasScheduledFrame` go false, so `pumpAndSettle()` always throws
/// ("pumpAndSettle timed out") against it, the same well-known pitfall as
/// the built-in indeterminate `LinearProgressIndicator`. That's a test-side
/// concern, not a reason to drop the animation from production code.
class _PillTrack extends StatefulWidget {
  final double? value;

  const _PillTrack({required this.value});

  @override
  State<_PillTrack> createState() => _PillTrackState();
}

class _PillTrackState extends State<_PillTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.value == null) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PillTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
      child: widget.value != null
          ? FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.value!.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(t.pill),
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(_controller.value * 2 - 1, 0),
                  child: FractionallySizedBox(
                    widthFactor: 0.3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.primary,
                        borderRadius: BorderRadius.circular(t.pill),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
