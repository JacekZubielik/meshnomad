import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/custom_style_overrides.dart';
import 'package:meshcore_open/theme/styles/custom_style.dart';
import 'package:meshcore_open/theme/styles/default_style.dart';

/// Reads the *rendered* fontSize of a `Text` located by [key] — the fully
/// resolved style (Text's own style merged with the ambient
/// `DefaultTextStyle`, e.g. from `ListTileThemeData.titleTextStyle`), not
/// just whatever `Text.style` happens to carry.
double _renderedFontSize(WidgetTester tester, Key key) {
  final richText = tester.widget<RichText>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
  );
  return richText.text.style!.fontSize!;
}

void main() {
  group('ListTile titles scale with the bodyMedium role (C2)', () {
    testWidgets(
      'a SwitchListTile title without an explicit style renders at the '
      'same size as bodyMedium text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: defaultStyle.dark,
            home: Scaffold(
              body: Column(
                children: [
                  SwitchListTile(
                    key: const Key('tile'),
                    title: const Text('Tile title'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  Text('bodyMedium text', key: const Key('body')),
                ],
              ),
            ),
          ),
        );

        final tileTitleSize = _renderedFontSize(tester, const Key('tile'));
        final bodyMediumSize = _renderedFontSize(tester, const Key('body'));
        expect(tileTitleSize, bodyMediumSize);
      },
    );

    testWidgets(
      'overriding bodyMedium via buildCustomStyle scales SwitchListTile '
      'titles along with it',
      (tester) async {
        final style = buildCustomStyle(
          const CustomStyleOverrides(fontSizeOverrides: {'bodyMedium': 20.0}),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: style.dark,
            home: Scaffold(
              body: Column(
                children: [
                  SwitchListTile(
                    key: const Key('tile'),
                    title: const Text('Tile title'),
                    value: true,
                    onChanged: (_) {},
                  ),
                  Text('bodyMedium text', key: const Key('body')),
                ],
              ),
            ),
          ),
        );

        final tileTitleSize = _renderedFontSize(tester, const Key('tile'));
        final bodyMediumSize = _renderedFontSize(tester, const Key('body'));
        expect(tileTitleSize, 20.0);
        expect(tileTitleSize, bodyMediumSize);
      },
    );
  });
}
