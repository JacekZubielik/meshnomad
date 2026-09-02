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
/// [MeshCard]'s own elevated-mode outer shadow LITERALLY
/// (`mesh_ui.dart`'s two-layer `boxShadow`):
///   layer 1: `alpha: 0.15`, `blurRadius: 2`
///   layer 2: `alpha: 0.22`, `blurRadius: 3`
/// — same color, same two alphas, same two distances, reused as fade-out
/// lengths instead of Gaussian blur radii (the closest inner-gradient
/// equivalent of a blur radius: 2026-09-02 feedback corrected an earlier,
/// invented single `fade: 8`/`4` value that didn't match either layer).
/// [showShadow] mirrors [MeshTokens.cardElevated] — the same app-wide
/// "Card shadow" toggle gates this exactly like every other shadow in the
/// app; both values must be resolved and passed in by the caller at
/// theme-construction time, since [paint] has no [BuildContext] to read
/// [MeshTokens.of] from (same constraint `DashedRoundedRectangleBorder`
/// above works around).
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
  });

  final Color shadowColor;
  final bool showShadow;

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

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (showShadow) {
      final rrect = borderRadius.resolve(textDirection).toRRect(rect);
      canvas.save();
      canvas.clipRRect(rrect);
      // MeshCard's own two literal boxShadow layers, mesh_ui.dart — smaller
      // one first so the larger, more visible layer paints on top.
      _paintEdgeGradient(canvas, rect, 0.15, 2);
      _paintEdgeGradient(canvas, rect, 0.22, 3);
      canvas.restore();
    }
    super.paint(canvas, rect, textDirection: textDirection);
  }
}
