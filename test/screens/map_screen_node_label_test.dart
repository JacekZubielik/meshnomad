import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/screens/map_screen.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/theme/mesh_theme.dart';

/// Mirrors the marker `child` built by `_buildNodeLabelMarker` in
/// `map_screen.dart` post-fix (06-map-bugs.md, extended 2026-08-30 for
/// content-sized width): no `FittedBox`, fixed `monoBody` size, `Text`
/// handles overflow via ellipsis only past `nodeLabelBubbleWidthMax`.
/// `_buildNodeLabelMarker` itself is a private `State` method (needs
/// `_overlayPanelColor` etc.), so this reproduces its widget shape 1:1 to
/// verify the fix pattern in isolation — see the widget test for the real
/// marker via a rendered `MapScreen` in a future pass if deeper coverage is
/// needed.
Widget _nodeLabelCard(String label) {
  return Builder(
    builder: (context) {
      final style = MeshTokens.of(
        context,
      ).monoBody(fontWeight: FontWeight.w700, color: Colors.white);
      final width = nodeLabelBubbleWidth(label, style, horizontalPadding: 12);
      return SizedBox(
        width: width,
        height: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(MeshTokens.of(context).xs),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      );
    },
  );
}

void main() {
  testWidgets('node label font size is identical for a short and a long name '
      '(no FittedBox scaling, 06-map-bugs.md)', (tester) async {
    const shortKey = Key('short');
    const longKey = Key('long');

    await tester.pumpWidget(
      MaterialApp(
        theme: MeshTheme.dark().copyWith(
          extensions: const [MeshTokens.defaultTokens],
        ),
        home: Scaffold(
          body: Column(
            children: [
              KeyedSubtree(key: shortKey, child: _nodeLabelCard('AB')),
              KeyedSubtree(
                key: longKey,
                child: _nodeLabelCard('Bardzo-Długa-Nazwa-Węzła-RPT-123'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No overflow/layout exception was thrown by pumpAndSettle above —
    // the long name must have been clipped with ellipsis, not overflowed.
    expect(tester.takeException(), isNull);

    RenderParagraph paragraphFor(Key key) {
      return tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      );
    }

    final shortSize = paragraphFor(shortKey).text.style!.fontSize;
    final longSize = paragraphFor(longKey).text.style!.fontSize;

    expect(shortSize, isNotNull);
    expect(shortSize, longSize);
  });

  test(
    'nodeLabelBubbleWidth grows with the label, shrinks for short names, '
    'and clamps at nodeLabelBubbleWidthMax (2026-08-30: was a fixed 140px '
    'box that clipped long names and left short ones adrift in whitespace)',
    () {
      const style = TextStyle(fontSize: 12, fontFamily: 'monospace');
      const padding = 12.0;

      final shortWidth = nodeLabelBubbleWidth(
        'AB',
        style,
        horizontalPadding: padding,
      );
      final mediumWidth = nodeLabelBubbleWidth(
        'Heltec-V3-Repeater',
        style,
        horizontalPadding: padding,
      );
      final extremeWidth = nodeLabelBubbleWidth(
        'A' * 500,
        style,
        horizontalPadding: padding,
      );

      // Content-sized: a longer label gets a wider bubble than a shorter one.
      expect(shortWidth, lessThan(mediumWidth));
      // A tiny label's bubble is still just its own padded size, not a
      // leftover fixed box (the old 140px minimum this replaces).
      expect(shortWidth, lessThan(140));
      // The clamp caps runaway names instead of growing unbounded.
      expect(extremeWidth, nodeLabelBubbleWidthMax);
      // Padding (plus the fixed measurement-drift slack) is always
      // included, even for an empty label.
      expect(
        nodeLabelBubbleWidth('', style, horizontalPadding: padding),
        padding + nodeLabelBubbleWidthSlack,
      );
    },
  );

  test('nodeLabelBubbleWidth measures at the real device text-scale rather '
      'than always assuming 1.0 (2026-08-30, Grok adversarial review: an '
      'under-measured width made the marker-list cache permanently clip '
      'labels on devices with a larger system font size)', () {
    const style = TextStyle(fontSize: 12, fontFamily: 'monospace');
    const padding = 12.0;
    // Short enough that even the scaled-up measurement stays under
    // nodeLabelBubbleWidthMax, so the clamp can't mask the comparison.
    const label = 'Heltec-V3';

    final unscaled = nodeLabelBubbleWidth(
      label,
      style,
      horizontalPadding: padding,
    );
    final scaledUp = nodeLabelBubbleWidth(
      label,
      style,
      horizontalPadding: padding,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(scaledUp, greaterThan(unscaled));
  });
}
