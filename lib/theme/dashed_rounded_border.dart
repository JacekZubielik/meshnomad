import 'dart:ui' show lerpDouble;

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
