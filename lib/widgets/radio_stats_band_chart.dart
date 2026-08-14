import 'package:flutter/material.dart';

import '../theme/mesh_theme.dart';
import '../theme/mesh_tokens.dart';

/// Radio-stats chart pair: an RSSI↔noise band on a shared dBm axis plus an
/// SNR strip on its own dB axis below, with one crosshair scrubbing both.
/// Deliberately separate from [StatsLineChart] — that widget stays the
/// single-series style shared by the simple stats views.
class RadioStatsBandChart extends StatefulWidget {
  const RadioStatsBandChart({
    super.key,
    required this.rssi,
    required this.noise,
    required this.snr,
    required this.noiseLabel,
    this.bandHeight = 140,
    this.stripHeight = 56,
  });

  final List<double> rssi;
  final List<double> noise;
  final List<double> snr;

  /// Localized series name for the noise floor ("RSSI"/"SNR" are acronyms
  /// and stay as-is).
  final String noiseLabel;
  final double bandHeight;
  final double stripHeight;

  @override
  State<RadioStatsBandChart> createState() => _RadioStatsBandChartState();
}

class _RadioStatsBandChartState extends State<RadioStatsBandChart> {
  static const double _padL = 40;
  static const double _padR = 8;

  int? _cursorIndex;

  void _updateCursor(double dx, double width) {
    final n = widget.noise.length;
    if (n < 2) return;
    final plot = width - _padL - _padR;
    if (plot <= 0) return;
    final idx = (((dx - _padL) / plot) * (n - 1)).round().clamp(0, n - 1);
    if (idx != _cursorIndex) setState(() => _cursorIndex = idx);
  }

  Widget _legendItem(String label, Color color, {bool dashed = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(14, 2),
          painter: _LegendSwatchPainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tokens = MeshTokens.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    // ink4 is tuned for the dark chart surface; the light surface needs the
    // light palette's muted ink. SNR mirrors snrColor's green, dimmed on
    // light for contrast against the chart background.
    final noiseColor = isLight ? MeshPalette.lightInk3 : tokens.ink4;
    final snrLineColor = isLight ? tokens.signalDim : tokens.signal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              _legendItem('RSSI', scheme.primary),
              const SizedBox(width: 14),
              _legendItem(widget.noiseLabel, noiseColor, dashed: true),
              const SizedBox(width: 14),
              _legendItem('SNR', snrLineColor),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _updateCursor(d.localPosition.dx, width),
              onHorizontalDragStart: (d) =>
                  _updateCursor(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) =>
                  _updateCursor(d.localPosition.dx, width),
              child: Column(
                children: [
                  SizedBox(
                    height: widget.bandHeight,
                    width: double.infinity,
                    child: CustomPaint(
                      key: const Key('radioStatsBandChart'),
                      painter: RadioStatsBandChartPainter(
                        rssi: List<double>.from(widget.rssi),
                        noise: List<double>.from(widget.noise),
                        snr: List<double>.from(widget.snr),
                        cursorIndex: _cursorIndex,
                        colorScheme: scheme,
                        textTheme: tt,
                        noiseColor: noiseColor,
                        snrColor: snrLineColor,
                        noiseLabel: widget.noiseLabel,
                        tokens: tokens,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: widget.stripHeight,
                    width: double.infinity,
                    child: CustomPaint(
                      key: const Key('radioStatsSnrStrip'),
                      painter: RadioStatsSnrStripPainter(
                        snr: List<double>.from(widget.snr),
                        cursorIndex: _cursorIndex,
                        colorScheme: scheme,
                        textTheme: tt,
                        lineColor: snrLineColor,
                        tokens: tokens,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

Path _dashPath(Path source, {double dash = 5, double gap = 4}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      out.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return out;
}

/// RSSI↔noise band: both series on one dBm axis, the area between them
/// filled — the band height is the link margin. Also hosts the crosshair
/// tooltip with all three readouts.
class RadioStatsBandChartPainter extends CustomPainter {
  RadioStatsBandChartPainter({
    required this.rssi,
    required this.noise,
    required this.snr,
    required this.cursorIndex,
    required this.colorScheme,
    required this.textTheme,
    required this.noiseColor,
    required this.snrColor,
    required this.noiseLabel,
    required this.tokens,
  });

  final List<double> rssi;
  final List<double> noise;
  final List<double> snr;
  final int? cursorIndex;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Color noiseColor;
  final Color snrColor;
  final String noiseLabel;
  final MeshTokens tokens;

  static const double _padL = 40;
  static const double _padR = 8;
  static const double _padT = 8;
  static const double _padB = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _paintFrame(canvas, size);
    if (rssi.length < 2 || noise.length != rssi.length) {
      final tp = _label('—');
      tp.paint(
        canvas,
        Offset(chart.left + 4, chart.top + chart.height / 2 - tp.height / 2),
      );
      return;
    }

    var minV = double.infinity;
    var maxV = double.negativeInfinity;
    for (final v in [...rssi, ...noise]) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    minV -= 2;
    maxV += 2;
    final span = maxV - minV;

    for (var i = 0; i <= 4; i++) {
      final v = maxV - span * i / 4;
      final tp = _label(v.round().toString());
      final y = chart.top + (chart.height * i / 4) - tp.height / 2;
      tp.paint(canvas, Offset(4, y));
    }

    Offset point(List<double> s, int i) => Offset(
      chart.left + chart.width * i / (s.length - 1),
      chart.bottom - ((s[i] - minV) / span) * chart.height,
    );

    final band = Path()..moveTo(point(rssi, 0).dx, point(rssi, 0).dy);
    for (var i = 1; i < rssi.length; i++) {
      band.lineTo(point(rssi, i).dx, point(rssi, i).dy);
    }
    for (var i = noise.length - 1; i >= 0; i--) {
      band.lineTo(point(noise, i).dx, point(noise, i).dy);
    }
    band.close();
    canvas.drawPath(
      band,
      Paint()..color = colorScheme.primary.withValues(alpha: 0.14),
    );

    canvas.drawPath(
      _dashPath(_seriesPath(noise, point)),
      Paint()
        ..color = noiseColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      _seriesPath(rssi, point),
      Paint()
        ..color = colorScheme.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    _endLabel(canvas, chart, 'RSSI', point(rssi, rssi.length - 1).dy);
    _endLabel(canvas, chart, noiseLabel, point(noise, noise.length - 1).dy);

    final cursor = cursorIndex;
    if (cursor != null) {
      final i = cursor.clamp(0, rssi.length - 1);
      final x = chart.left + chart.width * i / (rssi.length - 1);
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = colorScheme.outline
          ..strokeWidth = 1,
      );
      _paintTooltip(canvas, chart, i, x);
    }
  }

  Rect _paintFrame(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.xs)),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.xs)),
      Paint()
        ..color = colorScheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final chart = Rect.fromLTRB(
      _padL,
      _padT,
      size.width - _padR,
      size.height - _padB,
    );
    final grid = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    return chart;
  }

  Path _seriesPath(List<double> s, Offset Function(List<double>, int) point) {
    final path = Path()..moveTo(point(s, 0).dx, point(s, 0).dy);
    for (var i = 1; i < s.length; i++) {
      path.lineTo(point(s, i).dx, point(s, i).dy);
    }
    return path;
  }

  void _endLabel(Canvas canvas, Rect chart, String text, double lineY) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final y = (lineY - tp.height - 3).clamp(
      chart.top,
      chart.bottom - tp.height,
    );
    tp.paint(canvas, Offset(chart.right - tp.width - 2, y));
  }

  void _paintTooltip(Canvas canvas, Rect chart, int i, double x) {
    final secondsAgo = rssi.length - 1 - i;
    final valueStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurface,
    );
    TextSpan row(Color c, String text, {bool last = false}) => TextSpan(
      children: [
        TextSpan(
          text: '● ',
          style: textTheme.labelSmall?.copyWith(color: c),
        ),
        TextSpan(text: last ? text : '$text\n', style: valueStyle),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 't −$secondsAgo s\n',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          row(colorScheme.primary, 'RSSI ${rssi[i].round()} dBm'),
          row(
            noiseColor,
            '$noiseLabel ${noise[i].round()} dBm',
            last: i >= snr.length,
          ),
          if (i < snr.length)
            row(snrColor, 'SNR ${snr[i].toStringAsFixed(1)} dB', last: true),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 7.0;
    final w = tp.width + pad * 2;
    final h = tp.height + pad * 2;
    final left = x + 10 + w > chart.right ? x - w - 10 : x + 10;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, chart.top + 4, w, h),
      Radius.circular(tokens.xs),
    );
    canvas.drawRRect(rect, Paint()..color = colorScheme.surfaceContainerHigh);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, Offset(left + pad, chart.top + 4 + pad));
  }

  TextPainter _label(String text) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant RadioStatsBandChartPainter old) {
    return old.rssi.length != rssi.length ||
        old.cursorIndex != cursorIndex ||
        old.colorScheme != colorScheme ||
        (rssi.isNotEmpty && old.rssi.isNotEmpty && old.rssi.last != rssi.last);
  }
}

/// SNR on its own honest dB axis under the band chart — same time axis and
/// horizontal padding, so the shared crosshair lines up.
class RadioStatsSnrStripPainter extends CustomPainter {
  RadioStatsSnrStripPainter({
    required this.snr,
    required this.cursorIndex,
    required this.colorScheme,
    required this.textTheme,
    required this.lineColor,
    required this.tokens,
  });

  final List<double> snr;
  final int? cursorIndex;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Color lineColor;
  final MeshTokens tokens;

  static const double _padL = 40;
  static const double _padR = 8;
  static const double _padT = 6;
  static const double _padB = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.xs)),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.xs)),
      Paint()
        ..color = colorScheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final chart = Rect.fromLTRB(
      _padL,
      _padT,
      size.width - _padR,
      size.height - _padB,
    );
    if (snr.length < 2) return;

    final minV = snr.reduce((a, b) => a < b ? a : b) - 1;
    final maxV = snr.reduce((a, b) => a > b ? a : b) + 1;
    final span = maxV - minV;

    _tick(canvas, chart, maxV, chart.top);
    _tick(canvas, chart, minV, chart.bottom);

    double y(double v) => chart.bottom - ((v - minV) / span) * chart.height;

    if (minV < 0 && maxV > 0) {
      final zero = Path()
        ..moveTo(chart.left, y(0))
        ..lineTo(chart.right, y(0));
      canvas.drawPath(
        _dashPath(zero, dash: 2, gap: 3),
        Paint()
          ..color = colorScheme.outline
          ..strokeWidth = 1,
      );
    }

    final path = Path();
    for (var i = 0; i < snr.length; i++) {
      final p = Offset(
        chart.left + chart.width * i / (snr.length - 1),
        y(snr[i]),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'SNR',
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(chart.right - tp.width - 2, chart.top));

    final cursor = cursorIndex;
    if (cursor != null) {
      final i = cursor.clamp(0, snr.length - 1);
      final x = chart.left + chart.width * i / (snr.length - 1);
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = colorScheme.outline
          ..strokeWidth = 1,
      );
    }
  }

  void _tick(Canvas canvas, Rect chart, double value, double atY) {
    final tp = TextPainter(
      text: TextSpan(
        text: value.round().toString(),
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final y = (atY - tp.height / 2).clamp(0.0, chart.bottom);
    tp.paint(canvas, Offset(4, y));
  }

  @override
  bool shouldRepaint(covariant RadioStatsSnrStripPainter old) {
    return old.snr.length != snr.length ||
        old.cursorIndex != cursorIndex ||
        old.colorScheme != colorScheme ||
        (snr.isNotEmpty && old.snr.isNotEmpty && old.snr.last != snr.last);
  }
}

class _LegendSwatchPainter extends CustomPainter {
  _LegendSwatchPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(
      dashed ? _dashPath(line, dash: 3, gap: 3) : line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LegendSwatchPainter old) =>
      old.color != color || old.dashed != dashed;
}
