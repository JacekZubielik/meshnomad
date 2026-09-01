import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';

/// Tone of a [WindaMessage] — drives the icon and its color. Mapped to the
/// app's existing three-color status vocabulary
/// (`MeshTokens.signal`/`warn`/`alert`, `mesh_tokens.dart:117-123`), plus
/// `primary` for neutral info — no new palette entries.
enum WindaMessageTone { success, info, warning, error }

/// A single message-winda entry. Immutable value type — the owning screen's
/// state holds a `List<WindaMessage>` and adds/removes entries as events
/// happen; see `MeshScreenScaffold`.
class WindaMessage {
  final String text;
  final WindaMessageTone tone;

  /// Null = no action slot rendered. Non-null with [onAction] renders a
  /// `FilledButton` flush right of the text.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Reserved for a future auto-dismiss feature — NOT YET IMPLEMENTED.
  /// Neither `WindaHostController` nor `WindaHostOverlay` currently reads
  /// this field or starts a timer from it; today a message persists until
  /// the owning screen removes it from its `messages` list (e.g. Contacts
  /// clears its stall message by resetting `contactSyncTimedOut`).
  final Duration duration;

  const WindaMessage({
    required this.text,
    required this.tone,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 4),
  });

  /// Deliberately excludes [onAction] from equality/hash: closures aren't
  /// meaningfully comparable, and two different closure instances with
  /// equivalent behavior shouldn't be treated as "changed" for
  /// [WindaHostController.register]'s value-equality idempotency check —
  /// otherwise a screen that rebuilds a fresh (non-const) `WindaMessage`
  /// with the same text/tone/actionLabel/duration every frame (e.g. one
  /// built from a runtime l10n string, as Task 5 does) but a new `onAction`
  /// closure instance each time would defeat the no-op check entirely.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WindaMessage &&
        other.text == text &&
        other.tone == tone &&
        other.actionLabel == actionLabel &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(text, tone, actionLabel, duration);
}

/// Content widget for [WindaOverlay] — sibling to `WindaProgress`
/// (`winda_overlay.dart`), same shell, different content. No progress bar,
/// no percentage — that's `WindaProgress`'s territory.
class WindaMessageContent extends StatelessWidget {
  final WindaMessage message;

  const WindaMessageContent({super.key, required this.message});

  IconData get _icon => switch (message.tone) {
    WindaMessageTone.success => Icons.check_circle,
    WindaMessageTone.info => Icons.info,
    WindaMessageTone.warning => Icons.warning,
    WindaMessageTone.error => Icons.error,
  };

  Color _color(MeshTokens t) => switch (message.tone) {
    WindaMessageTone.success => t.signal,
    WindaMessageTone.info => t.primary,
    WindaMessageTone.warning => t.warn,
    WindaMessageTone.error => t.alert,
  };

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final color = _color(t);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.spacingSm, 0, t.spacingSm, t.spacingSm),
      child: Row(
        children: [
          // "LCD display" readout — matches SettingsValueStepper's valuePill
          // (Settings screens) EXACTLY: fill = `scheme.primary` @ 20% alpha
          // (not tone-tinted — only the icon carries the tone color, per
          // 2026-09-02 feedback), `t.sm` (rectangular, NOT `t.pill`) radius,
          // no border, centered mono text. Single-line + ellipsis by design —
          // a compact status readout, not a wrapped paragraph. `Flexible`
          // (loose fit), not `Expanded` (tight fit) — the pill hugs its own
          // content width and centers within the remaining row space, rather
          // than being forced to stretch across all of it (2026-09-02
          // feedback: it read as far too wide against how compact valuePill
          // actually looks in Settings).
          Flexible(
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacingSm,
                  vertical: t.spacingXxs,
                ),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(t.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, color: color, size: 16),
                    SizedBox(width: t.spacingXxs),
                    Flexible(
                      child: Text(
                        message.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: t.monoBody(color: onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (message.actionLabel case final label?) ...[
            SizedBox(width: t.spacingSm),
            FilledButton(onPressed: message.onAction, child: Text(label)),
          ],
        ],
      ),
    );
  }
}
