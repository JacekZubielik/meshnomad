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

  /// Auto-dismiss duration. No `persist` flag by design — every message
  /// dismisses eventually, matching the `showDismissibleSnackBar` mechanism
  /// this replaces (see docs/superpowers/specs/2026-09-01-winda-message-system-design.md).
  final Duration duration;

  const WindaMessage({
    required this.text,
    required this.tone,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 4),
  });
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
