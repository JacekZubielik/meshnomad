import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:meshcore_open/widgets/dotted_separator.dart';

@Preview(name: 'DottedSeparator — on dark bubble')
Widget dottedSeparatorPreview() {
  return const ColoredBox(
    color: Color(
      0xFF171D18,
    ), // dark on-surface, from mockup template.html:33/on-surface
    child: Padding(
      padding: EdgeInsets.all(24),
      child: DottedSeparator(
        color: Color(0xFFDFE4DC),
      ), // dark on-surface text color
    ),
  );
}
