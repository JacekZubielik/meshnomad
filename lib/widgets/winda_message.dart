import 'package:flutter/material.dart';

import '../theme/mesh_theme.dart' show MeshFonts;
import '../theme/mesh_tokens.dart';
import 'mesh_ui.dart';

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

  /// Null = no action slot rendered. Non-null with [actionIcon] and
  /// [onAction] renders a small circular icon-only button
  /// (`MeshCircleIconButton`) flush right of the text — [actionLabel] is
  /// used as its tooltip/semantic label, not as visible button text (kept
  /// as a required, always-legible label for screen readers even though
  /// nothing on screen renders it as text).
  final String? actionLabel;

  /// Icon shown in the action button. Required whenever [actionLabel] is
  /// set — defaults to a refresh glyph, the only action shape built so far
  /// (Contacts' "Resync"), but a future call site (e.g. Discovery's "Undo")
  /// passes its own.
  final IconData actionIcon;
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
    this.actionIcon = Icons.refresh,
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
        other.actionIcon == actionIcon &&
        other.duration == duration;
  }

  @override
  int get hashCode =>
      Object.hash(text, tone, actionLabel, actionIcon, duration);
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
      // Right inset matches MeshCard's default horizontal margin (16,
      // `t.spacingXs` — `mesh_ui.dart:79`), the same 16dp Flutter's Scaffold
      // uses for the add-contact/add-group FABs' distance from the screen
      // edge on this same screen — so the action button lines up with both
      // (2026-09-02 feedback: `t.spacingSm` read as flush against the edge).
      padding: EdgeInsets.fromLTRB(t.spacingSm, 0, t.spacingXs, t.spacingSm),
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
                        // Deliberately NOT `t.monoBody()` (2026-09-02,
                        // root-caused on-device after several wrong guesses
                        // — SelectionArea and the variable-font swap were
                        // both ruled out first): `monoBody()`'s
                        // `fontFeatures: [FontFeature.tabularFigures()]` +
                        // `letterSpacing: 0.2` combination renders a stray
                        // underline-shaped artifact under this text on this
                        // font/Skia/Android combination. Bisected by
                        // dropping both — text has no digits here anyway, so
                        // tabular-figure alignment buys nothing — leaving
                        // `monoBody()` itself untouched for every OTHER call
                        // site (Settings' SettingsValueStepper included,
                        // where digit alignment does matter and the bug
                        // hasn't surfaced).
                        style: TextStyle(
                          fontFamily: MeshFonts.mono,
                          fontFamilyFallback: MeshFonts.monoFallback,
                          fontSize: t.monoBodySize,
                          color: onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (message.actionLabel case final label?) ...[
            SizedBox(width: t.spacingSm),
            // Icon-only, no visible text — matches the smaller circular
            // treatment already used for meshMainAppBar's overflow icon
            // (32/16, `app_bar.dart`), not a full-size FilledButton, so the
            // action slot stays compact against the equally-compact LCD
            // pill (2026-09-02 feedback). `label` is exposed to screen
            // readers via `Semantics`, NOT `MeshCircleIconButton.tooltip` —
            // this widget is hosted by `WindaHostOverlay` above the
            // `Navigator` (root-overlay design, `winda_host_overlay.dart`),
            // so there is deliberately no ancestor `Overlay` here, and
            // `Tooltip` (which `MeshCircleIconButton.tooltip` wraps in)
            // hard-requires one (`No Overlay widget found` — caught by
            // `test/screens/contacts_screen_message_winda_test.dart`,
            // debug-assertion-only so it would have stayed silent on a
            // release build instead of ever being noticed).
            Semantics(
              label: label,
              button: true,
              child: MeshCircleIconButton(
                icon: message.actionIcon,
                onPressed: message.onAction,
                size: 32,
                iconSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
