import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';

/// The one line-chart style shared by every stats view (noise floor, BLE
/// RSSI, battery charge): rounded card, 4 gridlines, y-axis labels, single
/// primary-colored series over uniformly spaced samples.
class StatsLineChart extends StatelessWidget {
  final List<double> samples;
  final double height;

  const StatsLineChart({super.key, required this.samples, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _StatsLinePainter(
          // A single reading still draws (as a flat line) — battery polls
          // every 2 minutes, so waiting for two samples looked broken.
          samples: samples.length == 1
              ? [samples.first, samples.first]
              : List<double>.from(samples),
          colorScheme: Theme.of(context).colorScheme,
          textTheme: Theme.of(context).textTheme,
          tokens: MeshTokens.of(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StatsLinePainter extends CustomPainter {
  final List<double> samples;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final MeshTokens tokens;

  _StatsLinePainter({
    required this.samples,
    required this.colorScheme,
    required this.textTheme,
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = colorScheme.surfaceContainerHighest;
    final border = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.xs)),
      bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.xs)),
      border,
    );

    const padL = 40.0;
    const padR = 8.0;
    const padT = 8.0;
    const padB = 24.0;
    final chart = Rect.fromLTRB(
      padL,
      padT,
      size.width - padR,
      size.height - padB,
    );

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    if (samples.length < 2) {
      final tp = TextPainter(
        text: TextSpan(
          text: '—',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(chart.left + 4, chart.top + chart.height / 2 - tp.height / 2),
      );
      return;
    }

    double minV = samples.reduce((a, b) => a < b ? a : b);
    double maxV = samples.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 1) {
      minV -= 2;
      maxV += 2;
    }
    final span = maxV - minV;

    for (var i = 0; i <= 4; i++) {
      final v = maxV - span * i / 4;
      final tp = _yAxisLabel(v);
      final y = chart.top + (chart.height * i / 4) - tp.height / 2;
      tp.paint(canvas, Offset(4, y));
    }

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = chart.left + (chart.width * i / (samples.length - 1));
      final t = (samples[i] - minV) / span;
      final y = chart.bottom - t * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _StatsLinePainter oldDelegate) {
    return oldDelegate.samples.length != samples.length ||
        oldDelegate.colorScheme != colorScheme;
  }

  TextPainter _yAxisLabel(double v) {
    final tp = TextPainter(
      text: TextSpan(
        text: v.round().toString(),
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }
}
