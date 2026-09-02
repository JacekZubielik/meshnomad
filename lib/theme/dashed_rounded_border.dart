import 'dart:ui' show lerpDouble;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A [RoundedRectangleBorder] whose outline is drawn dashed — the "dotted"
/// button border mode of the Custom Style editor (2026-08-21). Everything
/// except [paint] behaves exactly like the superclass.
///
/// [copyWith] (and, defensively, [lerpFrom]/[lerpTo]) MUST be overridden
/// (2026-08-23 fix): the actual root cause was [copyWith] — `ButtonStyleButton`
/// internally merges its resolved `side` onto the resolved `shape` via
/// `shape.copyWith(side: resolvedSide)`, and the inherited
/// [RoundedRectangleBorder.copyWith] hardcodes a plain
/// `RoundedRectangleBorder(...)` as its return type regardless of the actual
/// runtime subclass — silently collapsing every 'dotted' button back to a
/// solid-shaped border (losing this class's [paint] override, `dash`, and
/// `gap` entirely) the instant it reached a real widget tree, even though the
/// constructed [ThemeData] itself, and every WidgetStateProperty resolution
/// on it, was always correct. `lerpFrom`/`lerpTo` have the identical
/// hardcoding problem for shape-change animations, so they're overridden too
/// even though `copyWith` alone was enough to reproduce and fix the bug.
/// Confirmed via a widget-level test
/// (test/theme/button_border_rendering_test.dart) after the theme-level
/// assertions in custom_style_test.dart passed and still failed to catch it —
/// a `WidgetStateProperty<OutlinedBorder?>.resolve()` correctly returning this
/// class is NOT sufficient proof it reaches the screen; `copyWith`/`lerpFrom`/
/// `lerpTo` are separate call sites Flutter's button internals use afterward.
class DashedRoundedRectangleBorder extends RoundedRectangleBorder {
  const DashedRoundedRectangleBorder({
    super.side,
    super.borderRadius,
    this.dash = 3.0,
    this.gap = 3.0,
  });

  final double dash;
  final double gap;

  @override
  DashedRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return DashedRoundedRectangleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
      dash: dash,
      gap: gap,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is DashedRoundedRectangleBorder) {
      return DashedRoundedRectangleBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          a.borderRadius,
          borderRadius,
          t,
        )!,
        dash: lerpDouble(a.dash, dash, t) ?? dash,
        gap: lerpDouble(a.gap, gap, t) ?? gap,
      );
    }
    if (a is RoundedRectangleBorder) {
      return DashedRoundedRectangleBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          a.borderRadius,
          borderRadius,
          t,
        )!,
        dash: dash,
        gap: gap,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is DashedRoundedRectangleBorder) {
      return DashedRoundedRectangleBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          borderRadius,
          b.borderRadius,
          t,
        )!,
        dash: lerpDouble(dash, b.dash, t) ?? dash,
        gap: lerpDouble(gap, b.gap, t) ?? gap,
      );
    }
    if (b is RoundedRectangleBorder) {
      return DashedRoundedRectangleBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          borderRadius,
          b.borderRadius,
          t,
        )!,
        dash: dash,
        gap: gap,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(side.width / 2);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }
}

/// A [CircleBorder] whose outline is drawn dashed — the circular +/- stepper
/// buttons (App Settings > Appearance and Custom Style editor's Buttons
/// section) must show the same line style ('dotted') the value they control
/// is currently set to (2026-08-23), not just solid-or-nothing. Same
/// `copyWith`/`lerpFrom`/`lerpTo` overrides as [DashedRoundedRectangleBorder]
/// for the same reason — see that class's doc comment.
class DashedCircleBorder extends CircleBorder {
  const DashedCircleBorder({super.side, this.dash = 3.0, this.gap = 3.0});

  final double dash;
  final double gap;

  @override
  DashedCircleBorder copyWith({BorderSide? side, double? eccentricity}) {
    return DashedCircleBorder(side: side ?? this.side, dash: dash, gap: gap);
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is DashedCircleBorder) {
      return DashedCircleBorder(
        side: BorderSide.lerp(a.side, side, t),
        dash: lerpDouble(a.dash, dash, t) ?? dash,
        gap: lerpDouble(a.gap, gap, t) ?? gap,
      );
    }
    if (a is CircleBorder) {
      return DashedCircleBorder(
        side: BorderSide.lerp(a.side, side, t),
        dash: dash,
        gap: gap,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is DashedCircleBorder) {
      return DashedCircleBorder(
        side: BorderSide.lerp(side, b.side, t),
        dash: lerpDouble(dash, b.dash, t) ?? dash,
        gap: lerpDouble(gap, b.gap, t) ?? gap,
      );
    }
    if (b is CircleBorder) {
      return DashedCircleBorder(
        side: BorderSide.lerp(side, b.side, t),
        dash: dash,
        gap: gap,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final circleRect = Rect.fromCircle(
      center: rect.center,
      radius: (rect.shortestSide - side.width) / 2,
    );
    final path = Path()..addOval(circleRect);
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }
}

/// A [RoundedRectangleBorder] that additionally paints a soft inner shadow
/// along the top and left inner edges — the dropdown-menu surface
/// (`popupMenuTheme`, shared by every `PopupMenuButton` in the app —
/// `SortFilterMenu`'s search/filter dropdown AND `meshMainAppBar`'s ⋮ menu)
/// (2026-09-02 feedback: give both the same "recessed panel" depth cue).
/// Flutter's [BoxShadow] has no inset/inner variant — this fakes one with two
/// edge-aligned linear gradients, clipped to the border's own rounded rect so
/// they never bleed past it.
///
/// [shadowColor] plus the two gradient bands hardcoded in [paint] reproduce
/// [MeshCard]'s own elevated-mode outer shadow's ORIGINAL vertical-only
/// values (`mesh_ui.dart`'s two-layer `boxShadow`, as calibrated pre-2026-09-02):
///   layer 1: `alpha: 0.15`, `blurRadius: 2`
///   layer 2: `alpha: 0.22`, `blurRadius: 3`
/// — same color, same two alphas, same two distances, reused as fade-out
/// lengths instead of Gaussian blur radii (the closest inner-gradient
/// equivalent of a blur radius: 2026-09-02 feedback corrected an earlier,
/// invented single `fade: 8`/`4` value that didn't match either layer).
/// **These two numbers are frozen, not live-derived** — `MeshCard`'s own
/// `boxShadow` was later redirected to bottom+right only (same day, separate
/// feedback) and its `blurRadius`/`offset` values changed accordingly; this
/// class deliberately keeps painting its inner shadow along the TOP/LEFT
/// edges (a "recessed panel" cue, the opposite direction from the outer
/// shadow on purpose) using the distances above, which no longer match
/// `MeshCard`'s current `boxShadow` numbers verbatim. If `MeshCard`'s shadow
/// is retuned again, this comment (and whether these two distances should
/// follow) needs a deliberate decision, not an assumption they still match.
/// [showShadow] mirrors [MeshTokens.cardElevated] and gates the OUTER
/// bottom+right shadow; [showInnerShadow] mirrors the separate
/// [MeshTokens.innerShadowEnabled] toggle (App Settings > Appearance, under
/// "Card shadow", 2026-09-02) and gates the inner top/left one — the two
/// can be turned off independently. All values must be resolved and passed
/// in by the caller at theme-construction time, since [paint] has no
/// [BuildContext] to read [MeshTokens.of] from (same constraint
/// `DashedRoundedRectangleBorder` above works around).
///
/// `copyWith`/`lerpFrom`/`lerpTo` overridden for the same reason documented
/// on [DashedRoundedRectangleBorder] above — required, not optional
/// hardening, per this file's established pattern.
class InnerShadowRoundedRectangleBorder extends RoundedRectangleBorder {
  const InnerShadowRoundedRectangleBorder({
    super.side,
    super.borderRadius,
    required this.shadowColor,
    required this.showShadow,
    required this.showInnerShadow,
  });

  final Color shadowColor;
  final bool showShadow;
  final bool showInnerShadow;

  @override
  InnerShadowRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return InnerShadowRoundedRectangleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
      shadowColor: shadowColor,
      showShadow: showShadow,
      showInnerShadow: showInnerShadow,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is InnerShadowRoundedRectangleBorder) {
      return InnerShadowRoundedRectangleBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          a.borderRadius,
          borderRadius,
          t,
        )!,
        shadowColor: Color.lerp(a.shadowColor, shadowColor, t) ?? shadowColor,
        showShadow: t < 0.5 ? a.showShadow : showShadow,
        showInnerShadow: t < 0.5 ? a.showInnerShadow : showInnerShadow,
      );
    }
    if (a is RoundedRectangleBorder) {
      return InnerShadowRoundedRectangleBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          a.borderRadius,
          borderRadius,
          t,
        )!,
        shadowColor: shadowColor,
        showShadow: showShadow,
        showInnerShadow: showInnerShadow,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is InnerShadowRoundedRectangleBorder) {
      return InnerShadowRoundedRectangleBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          borderRadius,
          b.borderRadius,
          t,
        )!,
        shadowColor: Color.lerp(shadowColor, b.shadowColor, t) ?? shadowColor,
        showShadow: t < 0.5 ? showShadow : b.showShadow,
        showInnerShadow: t < 0.5 ? showInnerShadow : b.showInnerShadow,
      );
    }
    if (b is RoundedRectangleBorder) {
      return InnerShadowRoundedRectangleBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          borderRadius,
          b.borderRadius,
          t,
        )!,
        shadowColor: shadowColor,
        showShadow: showShadow,
        showInnerShadow: showInnerShadow,
      );
    }
    return super.lerpTo(b, t);
  }

  void _paintEdgeGradient(
    Canvas canvas,
    Rect rect,
    double alpha,
    double distance,
  ) {
    final peak = shadowColor.withValues(alpha: alpha);
    final clear = shadowColor.withValues(alpha: 0);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, distance),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.left, rect.top + distance),
          [peak, clear],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, distance, rect.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.left + distance, rect.top),
          [peak, clear],
        ),
    );
  }

  /// [MeshCard]'s exact two `BoxShadow` layers (`mesh_ui.dart`, bottom+right
  /// directional recipe as of 2026-09-02) — literal, not live-derived, same
  /// caveat as this class's other doc comment. Kept as real `BoxShadow`s
  /// (not the `_paintEdgeGradient` linear-fade approximation the inner
  /// shadow above uses) specifically so [_paintOuterShadow] can hand them to
  /// `Canvas.drawRRect` via [BoxShadow.toPaint], which uses a true Gaussian
  /// `MaskFilter.blur` — a pixel-faithful match to what `MeshCard` itself
  /// paints, not an approximation of it.
  static List<BoxShadow> _outerShadowLayers(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.15),
      offset: const Offset(1.5, 1.5),
      blurRadius: 1.5,
    ),
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.22),
      offset: const Offset(2, 2),
      blurRadius: 2,
    ),
  ];

  /// Outer drop shadow, unclipped so it bleeds past the shape's own bottom
  /// and right edges onto whatever's behind the popup route — the
  /// counterpart to [_paintEdgeGradient]'s inner top/left shading, giving
  /// dropdown menus (`popupMenuTheme`, shared by `SortFilterMenu` and
  /// `meshMainAppBar`'s ⋮ menu) the same directional outer shadow as every
  /// [MeshCard] (2026-09-02 feedback: Material's own built-in `elevation`
  /// shadow is a different, symmetric, non-alpha-tunable rendering model
  /// that can't reproduce this — see `elevation: 0` at both call sites,
  /// `mesh_theme.dart`/`custom_style.dart`, which turns that mechanism off
  /// entirely in favor of this one). Safe to paint unclipped here because
  /// `PopupMenuButton`'s `Material` uses `clipBehavior: Clip.none` by
  /// default (`popup_menu.dart`) — nothing upstream clips this canvas to
  /// the shape's own bounds.
  void _paintOuterShadow(Canvas canvas, RRect rrect) {
    canvas.save();
    // Unlike a real BoxDecoration — which paints boxShadow FIRST, then
    // covers the shadow's own interior with its opaque fill, leaving only
    // the peek past the edges visible — Material's shape.paint() runs
    // AFTER the surface fill (`_MaterialInterior.build`, `material.dart`:
    // `PhysicalShape(child: _ShapeBorderPaint(shape: shape, ...))`). Without
    // excluding the panel's own interior here, drawRRect would paint the
    // shadow's full alpha as a solid tinted smudge across the whole panel
    // instead of a thin edge shadow (2026-09-02: looked like a "flare"/
    // convex highlight rather than a cast shadow — this fixed it).
    final exclusion = Path()
      ..addRect(rrect.outerRect.inflate(24))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.clipPath(exclusion);
    for (final shadow in _outerShadowLayers(shadowColor)) {
      canvas.drawRRect(rrect.shift(shadow.offset), shadow.toPaint());
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (showShadow || showInnerShadow) {
      final rrect = borderRadius.resolve(textDirection).toRRect(rect);
      if (showShadow) {
        _paintOuterShadow(canvas, rrect);
      }
      if (showInnerShadow) {
        canvas.save();
        canvas.clipRRect(rrect);
        // MeshCard's own two literal boxShadow layers, mesh_ui.dart —
        // smaller one first so the larger, more visible layer paints on
        // top.
        _paintEdgeGradient(canvas, rect, 0.15, 2);
        _paintEdgeGradient(canvas, rect, 0.22, 3);
        canvas.restore();
      }
    }
    super.paint(canvas, rect, textDirection: textDirection);
  }
}
