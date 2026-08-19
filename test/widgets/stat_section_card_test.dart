import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

Widget _wrap(Widget child, {double width = 400}) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(
      body: SizedBox(width: width, child: child),
    ),
  );
}

void main() {
  testWidgets(
    'StatSectionCard renders exactly one bordered card containing the title and its entries',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatSectionCard(
            title: 'Statystyki pakietów',
            children: [
              StatEntry(icon: Icons.upload, label: 'Wysłane', value: '19579'),
              StatEntry(
                icon: Icons.download,
                label: 'Otrzymano',
                value: '68906',
              ),
            ],
          ),
        ),
      );

      expect(find.byType(MeshCard), findsOneWidget);
      expect(find.text('STATYSTYKI PAKIETÓW'), findsOneWidget);
      expect(find.byType(StatEntry), findsNWidgets(2));
    },
  );

  testWidgets(
    'StatEntry shows the headline value in full and the flood/direct breakdown as a separate detail line '
    '(reproduces 2026-08-18 Pixel Fold truncation: "Razem: 19579, Zalew: 19224, B...")',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          width: 200,
          const StatEntry(
            icon: Icons.upload,
            label: 'Wysłane',
            value: '19579',
            detail: 'Zalew: 19224 · Bezpośrednio: 10',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('19579'), findsOneWidget);
      expect(find.text('Zalew: 19224 · Bezpośrednio: 10'), findsOneWidget);
    },
  );

  Widget statEntryWithMonoBodySize(double monoBodySize) {
    return MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: [
          MeshTokens.defaultTokens.copyWith(monoBodySize: monoBodySize),
        ],
      ),
      home: const Scaffold(
        body: SizedBox(
          width: 400,
          child: StatEntry(
            icon: Icons.upload,
            label: 'Wysłane',
            value: '19579',
          ),
        ),
      ),
    );
  }

  testWidgets(
    'StatEntry headline value fontSize is 2x the actual MeshTokens.defaultTokens.monoBodySize '
    '(11pt -> 22pt, 2026-08-18 operator decision: 11pt is the ideal "Mono — treść" default)',
    (tester) async {
      expect(MeshTokens.defaultTokens.monoBodySize, 11);
      await tester.pumpWidget(statEntryWithMonoBodySize(11));
      final text = tester.widget<Text>(find.text('19579'));
      expect(text.textSpan?.style?.fontSize, 22);
    },
  );

  testWidgets(
    'StatEntry headline value fontSize scales proportionally with MeshTokens.monoBodySize '
    '(2026-08-18 Pixel bug: hardcoded .copyWith(fontSize: 26) ignored the Custom Style Editor slider)',
    (tester) async {
      await tester.pumpWidget(statEntryWithMonoBodySize(18));
      final text = tester.widget<Text>(find.text('19579'));
      expect(text.textSpan?.style?.fontSize, 36);
    },
  );

  testWidgets(
    'StatEntry value and detail lines align to the label text left edge, not the icon '
    '(2026-08-18 Pixel bug: crossAxisAlignment.start aligned value/detail under the 28px icon column)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          width: 300,
          const StatEntry(
            icon: Icons.upload,
            label: 'Wysłane',
            value: '19579',
            detail: 'Zalew: 19224',
          ),
        ),
      );

      final labelLeft = tester.getTopLeft(find.text('WYSŁANE')).dx;
      final valueLeft = tester.getTopLeft(find.text('19579')).dx;
      final detailLeft = tester.getTopLeft(find.text('Zalew: 19224')).dx;

      expect(valueLeft, closeTo(labelLeft, 0.01));
      expect(detailLeft, closeTo(labelLeft, 0.01));
    },
  );
}
