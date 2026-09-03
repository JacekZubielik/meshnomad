import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../connector/meshcore_protocol.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../utils/emoji_utils.dart';
import 'dotted_separator.dart';

/// MeshCore shared design kit.
///
/// Building blocks used across all screens so the app reads as one product:
/// [SectionHeader], [MeshCard], [StatusChip], [StatTile], [AvatarCircle],
/// [SignalBars], [RouteChip], [PulseDot], [BottomSheetHeader] +
/// [showMeshSheet], [ErrorRetryCard], and [ListEntrance].

/// Small-caps mono section label, optionally with a trailing widget.
class SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: MeshTokens.of(
                context,
              ).accentLabel(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bordered surface card with press feedback. The standard container for
/// grouped content and tappable list entries.
class MeshCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final double? radius;

  /// Floating look: border dropped, fill bumped one surface level up
  /// (surfaceContainerHigh), and a soft drop shadow added instead — mockup
  /// .mockups/depth-shadows.html, "Wariant C bg + Wariant B shadow", accepted
  /// 2026-08-09, extended to every MeshCard app-wide the same day. Pass
  /// `elevated: false` at a call site to keep the old flat bordered look.
  final bool? elevated;

  /// Whether the elevated look also paints its drop shadow. `false` keeps
  /// the elevated fill and borderless shape but casts no shadow — for a
  /// bar whose shadow is cast by a [MeshCardEdgeShadow] elsewhere in the
  /// tree instead (the three search bars), so it isn't drawn twice.
  final bool castsShadow;

  /// Whether the flat (non-elevated) look paints its outline border.
  /// `false` for edge-to-edge bars (the search bars): with the app-wide
  /// `cardElevated` style toggle off they'd otherwise get a 1 px outline
  /// around a full-width bar, which reads as a stray frame, not a card.
  final bool outlined;

  const MeshCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.color,
    this.borderColor,
    this.radius,
    this.elevated,
    this.castsShadow = true,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveRadius = radius ?? MeshTokens.of(context).md;
    final effectiveElevated = elevated ?? MeshTokens.of(context).cardElevated;
    final borderRadius = BorderRadius.circular(effectiveRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: effectiveElevated || !outlined
          ? BorderSide.none
          : BorderSide(color: borderColor ?? scheme.outlineVariant),
    );
    final card = Material(
      color:
          color ??
          (effectiveElevated
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onLongPress!();
              },
        onSecondaryTap: onSecondaryTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return Padding(
      padding: margin,
      child: effectiveElevated && castsShadow
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: dropShadow(context),
              ),
              child: card,
            )
          : card,
    );
  }

  /// [MeshCard]'s own drop shadow, factored out so [MeshCardEdgeShadow] can
  /// cast the identical shadow from a different widget (see its doc
  /// comment for why that's needed).
  ///
  /// Bottom+right only, no top/left bleed (2026-09-02 feedback: a zero
  /// horizontal offset made blurRadius spread the shadow symmetrically
  /// around every edge, including top/left, which read as "surrounding"
  /// rather than a light-from-top-left cast). BoxShadow always blurs
  /// symmetrically around its own offset rect, so eliminating the top/left
  /// leak requires offset.dx/dy >= blurRadius — set equal to it here, which
  /// reduces to zero bleed on those two edges exactly. Solved for
  /// blurRadius == offset so the bottom edge keeps the same total reach as
  /// the original vertical-only mockup spec (`0 1px 2px .15, 0 1px 3px
  /// .22`: reach = blur+dy = 3, 4) — same values, mirrored onto the right
  /// edge too instead of being wasted above/left of the card.
  static List<BoxShadow> dropShadow(BuildContext context) => [
    BoxShadow(
      color: MeshTokens.of(context).cardShadow.withValues(alpha: 0.15),
      offset: const Offset(1.5, 1.5),
      blurRadius: 1.5,
    ),
    BoxShadow(
      color: MeshTokens.of(context).cardShadow.withValues(alpha: 0.22),
      offset: const Offset(2, 2),
      blurRadius: 2,
    ),
  ];
}

/// A zero-height strip that paints only [MeshCard.dropShadow] — no fill, no
/// size — for casting a search bar's own drop shadow across whatever is
/// beneath it in a *different* Stack layer than the real bar.
///
/// Why this exists (2026-09-03): Contacts/Channels/Map all lay out as
/// `Column[searchBar MeshCard, Expanded[Stack[scrollable content, winda]]]`.
/// A `Column` paints children in order, so the search bar's real shadow
/// (bleeding ~4px below its own box) gets bled into the Expanded's territory
/// but is then unconditionally overpainted by whatever that Expanded's
/// content renders at those same pixels — a scrolled-up card, or the map.
/// Reserving a permanent gap can't fix this: the list scrolls arbitrary
/// content through that exact strip forever, so no static padding keeps it
/// clear.
///
/// The fix is to cast the *same* shadow again from inside that Expanded's
/// own `Stack`, positioned as a Stack child painted *after* the scrollable
/// content but *before* the winda's `Positioned` — so it draws on top of
/// scrolled cards/map tiles (satisfying "content scrolls under the shadow"),
/// while the winda — painted last, as it always was — keeps covering it
/// exactly as it already covers the real bar's shadow (the `1b2f665b`
/// fix, `windaShadowOverlap`), completely unaffected by this addition.
class MeshCardEdgeShadow extends StatelessWidget {
  const MeshCardEdgeShadow({super.key});

  /// Height of the invisible source box the shadow is cast from. BoxShadow
  /// blurs a filled rect of the *source's* geometry, so the source must be
  /// tall like the real bar for its bottom-edge blur to reach full
  /// intensity — a 1 px source spread its tiny area over the same blur and
  /// came out ~3-4x fainter, effectively invisible (issue #149). Any value
  /// comfortably larger than the blur reach works; it's clipped anyway.
  static const double _sourceHeight = 40;

  /// Visible window below the edge: [MeshCard.dropShadow]'s reach is
  /// blur + dy = 4 px, plus slack for anti-aliasing.
  static const double _reach = 6;

  @override
  Widget build(BuildContext context) {
    // Same gate as MeshCard's own shadow: the app-wide "elevated cards"
    // style toggle off means no card shadows anywhere, this one included.
    if (!MeshTokens.of(context).cardElevated) return const SizedBox.shrink();
    return SizedBox(
      height: _reach,
      width: double.infinity,
      // Only the part of the shadow *below* the source's bottom edge may
      // show — the source sits above this window, over the real bar, and
      // painting its shadow there would darken the bar itself.
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -_sourceHeight,
              left: 0,
              right: 0,
              height: _sourceHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: MeshCard.dropShadow(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted pill chip for statuses: a dot or icon plus a short label.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;
  final double? fontSize;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulse = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize ?? MeshTokens.of(context).microLabelSize;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MeshTokens.of(context).pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: effectiveFontSize + 2, color: color)
          else
            PulseDot(color: color, size: 7, animate: pulse),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MeshTokens.of(context).mono(
                fontSize: effectiveFontSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact metric tile: icon, mono value (+ optional unit), small label.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return MeshCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: MeshTokens.of(context).accentLabel(
                    color: scheme.onSurfaceVariant,
                    fontSize: MeshTokens.of(context).microLabelSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: value,
              style: MeshTokens.of(
                context,
              ).monoBody(fontWeight: FontWeight.w600, color: scheme.onSurface),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: MeshTokens.of(
                      context,
                    ).monoCaption(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Grid of [StatTile]s (or similar fixed-height cards) whose column count
/// adapts to the available width instead of a hardcoded per-screen value —
/// avoids the truncation/inconsistency that comes from each screen picking
/// its own crossAxisCount and childAspectRatio independently.
class ResponsiveStatGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double mainAxisExtent;
  final double? spacing;

  const ResponsiveStatGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.maxColumns = 4,
    this.mainAxisExtent = 100,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? MeshTokens.of(context).spacingSm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / minTileWidth)
            .floor()
            .clamp(1, maxColumns);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// One label/value entry inside a [StatSectionCard] — no card chrome of its
/// own since it's one of several entries sharing a single parent card.
/// [detail] is a secondary caption line (e.g. a flood/direct breakdown) kept
/// separate from [value] so the headline number never has to share its line
/// budget with a long comma-separated sentence (2026-08-18 Pixel Fold bug:
/// a single-string "Razem: X, Zalew: Y, Bezpośrednio: Z" value truncated to
/// "Razem: X, Zalew: Y, B...").
class StatEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? detail;
  final Color? color;

  const StatEntry({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.detail,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    const iconSize = 28.0;
    final valueIndent = iconSize + tokens.spacingXs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: iconSize, color: color ?? scheme.primary),
            SizedBox(width: tokens.spacingXs),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: tokens.accentLabel(
                  color: scheme.onSurfaceVariant,
                  fontSize: tokens.microLabelSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacingXxs),
        Padding(
          padding: EdgeInsets.only(left: valueIndent),
          child: Text.rich(
            TextSpan(
              text: value,
              // Headline number is deliberately larger than monoBodySize
              // (2026-08-17 readability fix: it reads as a metric, not a
              // caption) but must still track the slider so the Custom
              // Style Editor "Mono — treść" control isn't a dead knob for
              // it — hence a multiple of the token instead of a literal.
              style: tokens
                  .monoBody(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  )
                  .copyWith(fontSize: tokens.monoBodySize * 2),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: tokens.monoCaption(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (detail != null) ...[
          SizedBox(height: tokens.spacingXxs),
          Padding(
            padding: EdgeInsets.only(left: valueIndent),
            child: Text(
              detail!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Groups a titled set of [StatEntry] tiles inside ONE bordered [MeshCard] —
/// the pattern from the Packet Stats "Podsumowanie" panel, applied wherever
/// a screen shows several related metrics (avoids the six-separate-boxes
/// noise a bordered [StatTile] grid produces for the same data).
class StatSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double mainAxisExtent;

  const StatSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.minTileWidth = 160,
    this.maxColumns = 4,
    this.mainAxisExtent = 108,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(tokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: tokens.accentLabel(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: tokens.spacingSm),
          ResponsiveStatGrid(
            minTileWidth: minTileWidth,
            maxColumns: maxColumns,
            mainAxisExtent: mainAxisExtent,
            spacing: tokens.spacingMd,
            children: children,
          ),
        ],
      ),
    );
  }
}

/// Deterministic avatar tint palette shared by contact tiles and chat
/// headers — keep the single source here; do not copy the literals.
List<Color> avatarTintPalette(MeshTokens tokens) => [
  tokens.primary,
  tokens.secondary,
  tokens.signal,
  tokens.warn,
  tokens.avatarTint5,
  tokens.avatarTint6,
];

/// Initials avatar with a deterministic per-name hue, or a fixed [color]
/// for node-type coloring. Optional [icon] replaces initials; optional
/// [emoji] takes precedence over both — content only, the circle's
/// background and border never change with it (2026-08-21 fix: the emoji
/// used to swap the whole decoration for a neutral one).
class AvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final IconData? icon;
  final String? emoji;

  /// Optional freshness/state signal (e.g. [NodeFreshness.colorOf]) drawn as
  /// a small corner badge, same visual language as the map marker's status
  /// badge (`_buildNodeMarkerWidget` in map_screen.dart) — a second,
  /// independent channel next to [color]'s node-type tint.
  final Color? freshnessColor;

  const AvatarCircle({
    super.key,
    required this.name,
    this.size = 40,
    this.color,
    this.icon,
    this.emoji,
    this.freshnessColor,
  });

  Color _colorFor(BuildContext context, String s) {
    final hues = avatarTintPalette(MeshTokens.of(context));
    // Hash the emoji-free name: an emoji in the name is avatar CONTENT
    // (see [emoji]) and must never shift the circle's tint (2026-08-21).
    final hashed = stripEmoji(s);
    var h = 0;
    for (final c in hashed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return hues[h % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final accent = color ?? _colorFor(context, name);
    final initials = _initials(name);
    final badgeSize = (size * 0.3).clamp(9.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Follows the Custom Style "pill" corner-radius slider
            // (2026-09-02 feedback: pill = 0 should turn the contact avatar
            // into a square, but a hardcoded BoxShape.circle ignored it
            // entirely) — BorderRadius.circular clamps to half the box's
            // own side, so this still renders fully round at pill's max
            // exactly like BoxShape.circle did.
            borderRadius: BorderRadius.circular(t.pill),
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(
                  emoji!,
                  style: MeshTokens.of(context).emoji(fontSize: size * 0.48),
                )
              : icon != null
              ? Icon(icon, size: size * 0.5, color: accent)
              : Text(
                  initials,
                  style: MeshTokens.of(context).mono(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
        ),
        if (freshnessColor != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: freshnessColor,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return (words.first.characters.take(1).toString() +
            words[1].characters.take(1).toString())
        .toUpperCase();
  }
}

/// Four-bar signal strength indicator driven by an SNR value (dB), colored
/// with the shared [MeshTokens.snrColor] ramp.
class SignalBars extends StatelessWidget {
  final double? snr;
  final double height;

  const SignalBars({super.key, required this.snr, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = MeshTokens.of(context).snrColor(snr, blocked: false);
    final active = snr == null
        ? 0
        : snr! > 0
        ? 4
        : snr! > -5
        ? 3
        : snr! > -12
        ? 2
        : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final on = i < active;
        return Container(
          width: 3,
          height: height * (0.4 + i * 0.2),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: on ? color : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// Chip describing how a message was routed: direct (with hop count) vs flood.
class RouteChip extends StatelessWidget {
  final bool isDirect;
  final int? hops;

  const RouteChip({super.key, required this.isDirect, this.hops});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // Reuses the same keys as the path-detail screens (channel_message_path_
    // screen.dart, contact_localization.dart) so "direct"/"flood" read
    // identically everywhere, and chat_hopsCount for its ICU plural — this
    // chip used to build its label from a hardcoded English literal.
    final label = isDirect
        ? (hops == null || hops == 0
              ? l10n.channelPath_directPath
              : l10n.chat_hopsCount(hops!))
        : l10n.channelPath_floodPath;
    final tokens = MeshTokens.of(context);
    return Container(
      // horizontal 6 has no exact token — spacingXxs (4) is nearest.
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacingXxs,
        vertical: tokens.spacingHairline,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        // Was tokens.xs (2026-09-02 feedback, same fix as MeshStatusBadge
        // above) — this chip is the same pill-shaped-label family, not a
        // card/panel that should use the xs/sm/md/lg scale.
        borderRadius: BorderRadius.circular(tokens.pill),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: tokens.labelShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDirect ? Icons.trending_flat : Icons.podcasts,
            size: 11,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            // Same uppercase-chip look SectionHeader uses (label.toUpperCase()
            // in mesh_ui.dart) — accentLabel's TextStyle has no text-transform
            // of its own, so the previous hardcoded literal being all-caps was
            // load-bearing for the visual style, not just content.
            label.toUpperCase(),
            style: tokens.accentLabel(
              color: scheme.onSurfaceVariant,
              fontSize: tokens.microLabelSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single source of truth for node-type accent color — shared by the
/// Contacts-list avatar ([contacts_screen.dart]'s `_ContactTile._avatarColor`)
/// and [ContactTypeBadge] so the two can never independently drift again (as
/// of 2026-08-19 they already had: the avatar used `mapSensor` for sensors,
/// the badge used `signal` — same bug class as the Room/Route color
/// collision this token system also fixes).
Color colorForContactType(MeshTokens tokens, int type) {
  switch (type) {
    case advTypeRepeater:
      return tokens.warn;
    case advTypeRoom:
      return tokens.roomActive;
    case advTypeSensor:
      return tokens.mapSensor;
    default:
      return tokens.primary; // chat
  }
}

/// Header type pill — border + text in the given accent color, background
/// filled with that same color at 20% alpha, no icon (2026-08-19 accepted
/// mockup, .mockups/contact-tile-badges.html; fill treatment added in the
/// 2026-08-19 refinement). One implementation for every card-header type
/// pill: contacts pass a type-derived color via [ContactTypeBadge], channel
/// cards pass their own type color directly (2026-08-29 channel-card
/// parity).
class MeshTypePill extends StatelessWidget {
  final String label;
  final Color color;

  const MeshTypePill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacingXxs,
        vertical: tokens.spacingHairline,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(tokens.pill),
        boxShadow: tokens.labelShadow,
      ),
      child: Text(
        label.toUpperCase(),
        style: tokens
            .monoCaption(color: color)
            .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }
}

/// Node-type pill next to a contact's name in the Contacts list — a
/// [MeshTypePill] colored by [colorForContactType].
class ContactTypeBadge extends StatelessWidget {
  final int type;
  final String label;

  const ContactTypeBadge({super.key, required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    return MeshTypePill(
      label: label,
      color: colorForContactType(MeshTokens.of(context), type),
    );
  }
}

/// Two-layer selection dot — the canonical single-choice indicator
/// (accepted variant B2, 2026-08-29; see
/// docs/superpowers/meshnomad-vault/templates/ui-patterns/dropdown-menu-row-schema.md).
/// Modeled on the real switchTheme grammar (mesh_theme.dart:603-614): a
/// tinted 20×20 track circle (primary @ 20% alpha, no outline) holding a
/// solid primary thumb that grows 8→12 on selection; the whole pair ghosts
/// to opacity .30 when unselected. Used by the sort/filter dropdown rows
/// and every selection-sheet ("winda") row.
class MeshSelectorDot extends StatelessWidget {
  final bool selected;

  const MeshSelectorDot({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: selected ? 1.0 : 0.30,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.2),
        ),
        alignment: Alignment.center,
        child: Container(
          width: selected ? 12 : 8,
          height: selected ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// One badge inside [ContactBadgeRow] — text + 1px border only, no icon.
/// Ghosting (opacity 0.30) signals "exists but inactive" without removing
/// the element, so sibling badges never change position.
class MeshStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  /// Filled background — Favorite, GPS and Route use this when active
  /// (2026-08-21 refinement); the remaining badges stay border-only (null)
  /// as accepted 2026-08-19. Text
  /// always renders in [color] regardless — no separate "ink" color; a
  /// 20%-alpha fill of the same hue stays legible under it (2026-08-19
  /// refinement, corrected from an earlier 80%-alpha + white-text attempt).
  final Color? fillColor;

  /// Tap handler — null means inert (2026-08-19: ghosted Favorite/GPS/Route
  /// states, and every one of the other 5 badges, pass null here).
  final VoidCallback? onTap;

  const MeshStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.active,
    this.fillColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final badge = Opacity(
      opacity: active ? 1.0 : 0.30,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingXxs,
          vertical: tokens.spacingHairline,
        ),
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: color, width: 1),
          // Was tokens.xs (2026-09-02 feedback: didn't react to the Custom
          // Style "pill" slider at all) — this is the same pill-chip family
          // as MeshTypePill, which already correctly used tokens.pill; the
          // xs/pill split between two visually-identical chip kinds was the
          // actual bug the slider test surfaced.
          borderRadius: BorderRadius.circular(tokens.pill),
          boxShadow: tokens.labelShadow,
        ),
        child: Text(
          label.toUpperCase(),
          // Badge row now sits below its own dashed separator (2026-08-20
          // refinement), so labels shrink to 3/4 of the base mono-caption
          // size to keep the row compact while leaving room to breathe.
          style: tokens
              .monoCaption(color: color)
              .copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                fontSize: tokens.monoCaptionSize * 0.75,
              ),
        ),
      ),
    );
    if (onTap == null) return badge;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badge,
    );
  }
}

/// Fixed-order row of contact status badges — GPS, Route, Smaz, Lang, Time
/// (order per 2026-08-29 user spec), always in that order, every one always
/// rendered (ghosted via [MeshStatusBadge] when inactive/unavailable so
/// position never shifts), plus right-aligned mute-bell and favorite-star
/// icons (channel-card parity). The star replaced the former FAVORITES
/// badge (2026-08-28): always tappable, toggles either direction.
class ContactBadgeRow extends StatelessWidget {
  final bool isFavorite;
  final bool hasLocation;
  final bool isSmazEnabled;

  /// Null = route unknown for this contact; renders a ghosted placeholder.
  final String? routeLabel;

  /// Per-contact translation target language code; null = inherits the
  /// app-wide setting (ghost 'LANG' pill — 2026-08-29, channel-card parity).
  final String? languageCode;
  final String timeLabel;
  final bool isUnread;
  final bool isMuted;

  /// Tap targets (2026-08-19 refinement). Favorite/mute/lang always fire
  /// regardless of state (they toggle or open a picker). GPS/Route only
  /// fire when their own badge is active — gated INSIDE build() below, not
  /// by the caller, so a ghosted badge is never accidentally wired live.
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onGpsTap;
  final VoidCallback? onRouteTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onMuteTap;

  const ContactBadgeRow({
    super.key,
    required this.isFavorite,
    required this.hasLocation,
    required this.isSmazEnabled,
    required this.routeLabel,
    required this.timeLabel,
    required this.isUnread,
    this.languageCode,
    this.isMuted = false,
    this.onFavoriteTap,
    this.onGpsTap,
    this.onRouteTap,
    this.onLanguageTap,
    this.onMuteTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final neutral = scheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: tokens.spacingXxs,
            runSpacing: tokens.spacingXxs,
            children: [
              MeshStatusBadge(
                label: 'GPS',
                color: tokens.primary,
                active: hasLocation,
                fillColor: hasLocation
                    ? tokens.primary.withValues(alpha: 0.2)
                    : null,
                onTap: hasLocation ? onGpsTap : null,
              ),
              MeshStatusBadge(
                label: routeLabel ?? context.l10n.contacts_routeUnknown,
                color: tokens.routeActive,
                active: routeLabel != null,
                fillColor: routeLabel != null
                    ? tokens.routeActive.withValues(alpha: 0.2)
                    : null,
                onTap: routeLabel != null ? onRouteTap : null,
              ),
              MeshStatusBadge(
                label: 'Smaz',
                color: neutral,
                active: isSmazEnabled,
              ),
              MeshStatusBadge(
                label: languageCode?.toUpperCase() ?? 'LANG',
                color: tokens.primary,
                active: languageCode != null,
                fillColor: languageCode != null
                    ? tokens.primary.withValues(alpha: 0.2)
                    : null,
                onTap: onLanguageTap,
              ),
              MeshStatusBadge(
                label: timeLabel,
                color: isUnread ? tokens.primary : neutral,
                active: true,
                fillColor: (isUnread ? tokens.primary : neutral).withValues(
                  alpha: 0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacingXxs),
        GestureDetector(
          onTap: onMuteTap,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: isMuted ? 1.0 : 0.30,
            child: Icon(
              isMuted ? Icons.notifications_off : Icons.notifications,
              size: 18,
              color: tokens.warn,
            ),
          ),
        ),
        SizedBox(width: tokens.spacingXxs),
        GestureDetector(
          onTap: onFavoriteTap,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: isFavorite ? 1.0 : 0.30,
            child: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              size: 18,
              color: tokens.warn,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small status dot, optionally with a soft breathing animation.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const PulseDot({
    super.key,
    required this.color,
    this.size = 8,
    this.animate = false,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy `late final` initializer would run on first
  // access — which can be dispose(), where ticker creation throws.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.animate
          ? Tween(begin: 0.35, end: 1.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            )
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.45),
              blurRadius: widget.size * 0.7,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared circular tinted icon button — the "-/+ stepper" visual family
/// (`primary` @ 20% fill, `primary` icon, `CircleBorder` shape). Originally
/// duplicated across the board-picker stepper, the Flasher refresh button,
/// and the Flasher ⋮ menu icon — this is the single definition all three
/// now use.
///
/// By default (`decorative: false`), always renders a real `IconButton`, so
/// `onPressed: null` gets Material's normal disabled/dimmed look — this is
/// what the board-stepper's `boards.isEmpty` case needs, and works exactly
/// as the original `_circleButton` did, with proper accessibility semantics.
///
/// Pass `decorative: true` to render a non-interactive bare circle (e.g.
/// embedded as a `PopupMenuButton`'s `child`, where the PopupMenuButton
/// itself owns the tap) — in this case the icon is always full-brightness
/// since it's never itself interactive.
class MeshCircleIconButton extends StatelessWidget {
  const MeshCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 36,
    this.iconSize = 18,
    this.tooltip,
    this.decorative = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);
    final circle = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          // Follows the Custom Style "pill" corner-radius slider (2026-09-02
          // feedback: setting it to 0 left this circle untouched) — a
          // hardcoded CircleBorder ignored it entirely. `BorderRadius.circular`
          // clamps to half the box's own side automatically, so this still
          // renders fully round at pill's max (40) exactly like CircleBorder
          // did, and squares off toward pill = 0.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.pill),
          ),
          color: scheme.primary.withValues(alpha: 0.2),
        ),
        child: decorative
            ? Icon(icon, size: iconSize, color: scheme.primary)
            : IconButton(
                padding: EdgeInsets.zero,
                iconSize: iconSize,
                color: scheme.primary,
                icon: Icon(icon),
                onPressed: onPressed,
              ),
      ),
    );
    return tooltip == null ? circle : Tooltip(message: tooltip!, child: circle);
  }
}

/// Standard modal sheet header: drag handle, title, optional subtitle and
/// trailing action, and a close button.
class BottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: scheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows a modal bottom sheet with the app-standard shape, scroll behavior
/// and safe-area handling. Pair the content with [BottomSheetHeader].
///
/// The sheet's own background is painted explicitly here (read fresh from
/// [Theme.of] inside this builder) rather than left to
/// [ThemeData.bottomSheetTheme] — a sheet that edits the very token driving
/// its own background color (the custom style editor's color picker) needs
/// a widget in the tree that unambiguously re-subscribes to [Theme] on every
/// rebuild; `backgroundColor: Colors.transparent` below removes Flutter's
/// own bottom-sheet chrome so there's no stale layer painting underneath it.
Future<T?> showMeshSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: false,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final bottomSheetTheme = Theme.of(context).bottomSheetTheme;
      return Material(
        color:
            bottomSheetTheme.modalBackgroundColor ??
            bottomSheetTheme.backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerLow,
        shape: bottomSheetTheme.shape,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: builder(context),
        ),
      );
    },
  );
}

/// Inline error surface with an optional retry action.
class ErrorRetryCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ErrorRetryCard({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      color: scheme.error.withValues(alpha: 0.08),
      borderColor: scheme.error.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: scheme.error),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(retryLabel ?? 'Retry')),
        ],
      ),
    );
  }
}

/// Staggered fade + slide entrance for list items. Wrap each item and pass
/// its [index]; animation only plays once per widget lifecycle.
class ListEntrance extends StatefulWidget {
  final int index;
  final Widget child;

  const ListEntrance({super.key, required this.index, required this.child});

  @override
  State<ListEntrance> createState() => _ListEntranceState();
}

class _ListEntranceState extends State<ListEntrance>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy `late final` initializer would run on first
  // access — which can be dispose(), where ticker creation throws.
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final delay = Duration(milliseconds: 24 * widget.index.clamp(0, 12));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Icon + title/subtitle row with a trailing chevron — the shared building
/// block for every Settings card row (Node/Location/Actions/Export/Debug
/// screens). Icon defaults to the primary accent; pass [iconColor]/
/// [titleColor] for a warn/alert semantic row (e.g. "Reboot device").
class SettingsTappableTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  const SettingsTappableTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    final effectiveIconColor = iconColor ?? t.primary;
    final effectiveTitleColor = titleColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingSm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: effectiveIconColor),
            SizedBox(width: t.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: effectiveTitleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Subtitle keeps the default style color even when the
                  // title is accent-colored (user spec 2026-08-23: only the
                  // TITLE signals warn/alert; supplementary text stays
                  // small and un-forced like every other tile).
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Canonical dropdown-menu action row (2026-09-02) — the plain-icon "Mode B"
/// row [[dropdown-menu-row-schema]] anticipated but no menu had used yet:
/// same geometry as `SortFilterMenu`'s `_MenuOptionRow`/`_MenuOptionLeading`
/// (fixed 20×20 leading slot, `bodyMedium` text, `t.spacingXxs + 4` gap), but
/// for an action row that is never "selected" — no fill, no selector dot.
/// Use via [meshMenuActionItem] rather than directly, so the surrounding
/// `PopupMenuItem`'s padding/height also match the schema.
class MeshMenuActionRow extends StatelessWidget {
  final IconData? icon;
  final String label;

  /// Overrides the icon color for a destructive action (e.g. "Disconnect")
  /// — the one deliberate exception to the schema's "always scheme.primary"
  /// rule, predating this row's extraction. The label stays un-tinted.
  final Color? iconColor;

  /// Escape hatch for a leading visual that isn't a plain [IconData] (e.g.
  /// Map's `LosIcon`, a custom Symbols-based glyph) — sized/colored by the
  /// caller to match [icon]'s 18px/`scheme.primary` convention. Exactly one
  /// of [icon]/[leadingWidget] should be set.
  final Widget? leadingWidget;

  const MeshMenuActionRow({
    super.key,
    this.icon,
    required this.label,
    this.iconColor,
    this.leadingWidget,
  }) : assert(
         (icon == null) != (leadingWidget == null),
         'pass exactly one of icon/leadingWidget',
       );

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Same "pill" row container as SortFilterMenu's `_MenuOptionRow`
    // (`list_filter_widget.dart:179-185`) — margin/padding/radius, just
    // never filled (an action row is never "selected") — this row was
    // missing it entirely (2026-09-02 feedback: read as an old, flatter
    // style next to the search-filter dropdown's rounded rows).
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.buttonRadius),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child:
                leadingWidget ??
                Icon(icon, size: 18, color: iconColor ?? scheme.primary),
          ),
          SizedBox(width: t.spacingXxs + 4),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One action row of a dropdown menu, wrapped in the schema's canonical
/// `PopupMenuItem` geometry (horizontal gutter 10, row height 38) — pass the
/// result straight into a `PopupMenuButton.itemBuilder` list.
PopupMenuItem<T> meshMenuActionItem<T>({
  IconData? icon,
  required String label,
  required VoidCallback onTap,
  Color? iconColor,
  Widget? leadingWidget,
}) {
  return PopupMenuItem<T>(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    height: 38,
    onTap: onTap,
    child: MeshMenuActionRow(
      icon: icon,
      label: label,
      iconColor: iconColor,
      leadingWidget: leadingWidget,
    ),
  );
}

/// Section/group separator for a dropdown menu — [DottedSeparator], never
/// the solid `PopupMenuDivider`, per the schema.
PopupMenuItem<T> meshMenuDivider<T>(BuildContext context) {
  return PopupMenuItem<T>(
    enabled: false,
    height: 13,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: DottedSeparator(color: Theme.of(context).colorScheme.outlineVariant),
  );
}
