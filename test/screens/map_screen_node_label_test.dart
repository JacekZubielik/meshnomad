import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';

/// Mirrors the marker `child` built by `_buildNodeLabelMarker` in
/// `map_screen.dart` post-fix (06-map-bugs.md): no `FittedBox`, fixed
/// `monoBody` size, `Text` handles overflow via ellipsis. `_buildNodeLabelMarker`
/// itself is a private `State` method (needs `_overlayPanelColor` etc.), so
/// this reproduces its widget shape 1:1 to verify the fix pattern in
/// isolation — see the widget test for the real marker via a rendered
/// `MapScreen` in a future pass if deeper coverage is needed.
Widget _nodeLabelCard(String label) {
  return SizedBox(
    width: 140,
    height: 24,
    child: Builder(
      builder: (context) {
        return Container(
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
            style: MeshTokens.of(
              context,
            ).monoBody(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        );
      },
    ),
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
}
