import 'package:flutter/material.dart';

/// A delicate dotted horizontal rule — separates a chat bubble's footer
/// (hops/via or the timestamp) from the message content at a glance.
/// The caller passes the bubble's text color so the dots keep contrast on
/// any bubble background in any color profile.
class DottedSeparator extends StatelessWidget {
  const DottedSeparator({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(painter: _DottedLinePainter(color)),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;

  _DottedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 2.0;
    const gap = 3.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0.0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
