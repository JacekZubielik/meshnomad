import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';

/// Widest caption any app-bar indicator shows ('-103 dBm' class of values).
/// Every caption box is sized to this prototype so indicator widths never
/// change with the value and the separator rhythm stays constant.
const String _captionPrototype = '-000dBm';

TextStyle indicatorCaptionStyle(BuildContext context, {Color? color}) {
  return MeshTokens.of(
    context,
  ).monoCaption(color: color).copyWith(fontWeight: FontWeight.w600);
}

double indicatorCaptionWidth(BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(
      text: _captionPrototype,
      style: indicatorCaptionStyle(context),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Fixed-width, center-aligned caption under an app-bar indicator icon.
/// Longer values are ellipsized instead of pushing the neighbours around.
class IndicatorCaption extends StatelessWidget {
  final String text;
  final Color? color;

  const IndicatorCaption(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: indicatorCaptionWidth(context),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: indicatorCaptionStyle(context, color: color),
      ),
    );
  }
}
