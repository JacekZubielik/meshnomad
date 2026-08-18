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
    'StatTile wraps long values onto two lines instead of truncating to one',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatTile(
            icon: Icons.timer,
            label: 'Uptime',
            value: '3 days 5h 23m 21s',
          ),
        ),
      );

      final valueText = tester.widget<Text>(
        find
            .descendant(of: find.byType(StatTile), matching: find.byType(Text))
            .last,
      );

      expect(valueText.maxLines, 2);
    },
  );

  testWidgets(
    'ResponsiveStatGrid places tiles side-by-side when the width fits more than one column',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          width: 800,
          const ResponsiveStatGrid(
            children: [
              StatTile(icon: Icons.timer, label: 'Uptime', value: '1'),
              StatTile(icon: Icons.battery_full, label: 'Battery', value: '2'),
            ],
          ),
        ),
      );

      final positions = tester
          .widgetList<StatTile>(find.byType(StatTile))
          .map((w) => tester.getTopLeft(find.byWidget(w)))
          .toList();

      expect(positions[0].dy, positions[1].dy);
      expect(positions[1].dx, greaterThan(positions[0].dx));
    },
  );

  testWidgets(
    'ResponsiveStatGrid stacks tiles into one column when the width is too narrow',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          width: 200,
          const ResponsiveStatGrid(
            children: [
              StatTile(icon: Icons.timer, label: 'Uptime', value: '1'),
              StatTile(icon: Icons.battery_full, label: 'Battery', value: '2'),
            ],
          ),
        ),
      );

      final positions = tester
          .widgetList<StatTile>(find.byType(StatTile))
          .map((w) => tester.getTopLeft(find.byWidget(w)))
          .toList();

      expect(positions[0].dx, positions[1].dx);
      expect(positions[1].dy, greaterThan(positions[0].dy));
    },
  );

  testWidgets(
    'ResponsiveStatGrid does not overflow a tile whose value wraps to two lines '
    '(reproduces 2026-08-18 Pixel Fold "BOTTOM OVERFLOWED BY 13 PIXELS")',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          width: 480,
          const ResponsiveStatGrid(
            children: [
              StatTile(
                icon: Icons.download,
                label: 'Czas odbioru RX',
                value: '0 dni 10h 53m 15s',
              ),
              StatTile(
                icon: Icons.upload,
                label: 'Wysłane',
                value: 'Razem: 19573, Zalew: 19218, B...',
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
