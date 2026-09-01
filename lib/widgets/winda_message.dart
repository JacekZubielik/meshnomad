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
    return Padding(
      padding: EdgeInsets.fromLTRB(t.spacingXs, 0, t.spacingXs, t.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: color, size: 20),
          SizedBox(width: t.spacingSm),
          Expanded(
            child: Text(
              message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.ink3),
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
