import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../connector/meshcore_protocol.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveRadius = radius ?? MeshTokens.of(context).md;
    final effectiveElevated = elevated ?? MeshTokens.of(context).cardElevated;
    final borderRadius = BorderRadius.circular(effectiveRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: effectiveElevated
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
      child: effectiveElevated
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                // 0 1px 2px rgba(0,0,0,.15), 0 1px 3px rgba(0,0,0,.22) — mockup Wariant B.
                boxShadow: [
                  BoxShadow(
                    color: MeshTokens.of(
                      context,
                    ).cardShadow.withValues(alpha: 0.15),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: MeshTokens.of(
                      context,
                    ).cardShadow.withValues(alpha: 0.22),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: card,
            )
          : card,
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
/// for node-type coloring. Optional [icon] replaces initials.
class AvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final IconData? icon;

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
    this.freshnessColor,
  });

  Color _colorFor(BuildContext context, String s) {
    final hues = avatarTintPalette(MeshTokens.of(context));
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return hues[h % hues.length];
  }

  @override
  Widget build(BuildContext context) {
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
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: icon != null
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
        borderRadius: BorderRadius.circular(tokens.xs),
        border: Border.all(color: scheme.outlineVariant),
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

/// Node-type pill next to a contact's name in the Contacts list — border +
/// text in the type's accent color (see [colorForContactType]), background
/// filled with that same color at 20% alpha, no icon (2026-08-19 accepted
/// mockup, .mockups/contact-tile-badges.html; fill treatment added in the
/// 2026-08-19 refinement, uniform across all 4 types).
class ContactTypeBadge extends StatelessWidget {
  final int type;
  final String label;

  const ContactTypeBadge({super.key, required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final color = colorForContactType(tokens, type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacingXs,
        vertical: tokens.spacingHairline,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(tokens.pill),
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

/// One badge inside [ContactBadgeRow] — text + 1px border only, no icon.
/// Ghosting (opacity 0.30) signals "exists but inactive" without removing
/// the element, so sibling badges never change position.
class _ContactBadge extends StatelessWidget {
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

  const _ContactBadge({
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
          horizontal: tokens.spacingXs,
          vertical: tokens.spacingHairline,
        ),
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(tokens.xs),
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

/// Fixed-order row of contact status badges — Favorite, GPS, Smaz, Route,
/// Time, always in that order, every one always rendered
/// (ghosted via [_ContactBadge] when inactive/unavailable so position never
/// shifts). Accepted mockup: .mockups/contact-tile-badges.html, 2026-08-19.
class ContactBadgeRow extends StatelessWidget {
  final bool isFavorite;
  final bool hasLocation;
  final bool isSmazEnabled;

  /// Null = route unknown for this contact; renders a ghosted placeholder.
  final String? routeLabel;
  final String timeLabel;
  final bool isUnread;

  /// Tap targets (2026-08-19 refinement). Favorite always fires regardless
  /// of state (toggles either direction). GPS/Route only fire when their
  /// own badge is active — gated INSIDE build() below, not by the caller,
  /// so a ghosted badge is never accidentally wired live.
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onGpsTap;
  final VoidCallback? onRouteTap;

  const ContactBadgeRow({
    super.key,
    required this.isFavorite,
    required this.hasLocation,
    required this.isSmazEnabled,
    required this.routeLabel,
    required this.timeLabel,
    required this.isUnread,
    this.onFavoriteTap,
    this.onGpsTap,
    this.onRouteTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final neutral = scheme.onSurfaceVariant;
    return Wrap(
      spacing: tokens.spacingXxs,
      runSpacing: tokens.spacingXxs,
      children: [
        _ContactBadge(
          label: context.l10n.listFilter_favorites,
          color: tokens.warn,
          active: isFavorite,
          fillColor: isFavorite ? tokens.warn.withValues(alpha: 0.2) : null,
          onTap: onFavoriteTap,
        ),
        _ContactBadge(
          label: 'GPS',
          color: tokens.primary,
          active: hasLocation,
          fillColor: hasLocation ? tokens.primary.withValues(alpha: 0.2) : null,
          onTap: hasLocation ? onGpsTap : null,
        ),
        _ContactBadge(label: 'Smaz', color: neutral, active: isSmazEnabled),
        _ContactBadge(
          label: routeLabel ?? context.l10n.contacts_routeUnknown,
          color: tokens.routeActive,
          active: routeLabel != null,
          fillColor: routeLabel != null
              ? tokens.routeActive.withValues(alpha: 0.2)
              : null,
          onTap: routeLabel != null ? onRouteTap : null,
        ),
        _ContactBadge(
          label: timeLabel,
          color: isUnread ? tokens.primary : neutral,
          active: true,
          fillColor: (isUnread ? tokens.primary : neutral).withValues(
            alpha: 0.2,
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
