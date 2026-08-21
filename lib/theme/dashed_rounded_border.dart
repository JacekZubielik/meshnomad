import 'package:flutter/material.dart';

/// A [RoundedRectangleBorder] whose outline is drawn dashed — the "dotted"
/// button border mode of the Custom Style editor (2026-08-21). Everything
/// except [paint] behaves exactly like the superclass.
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
