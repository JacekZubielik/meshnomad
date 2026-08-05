import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshcore_open/widgets/mesh_ui.dart';

void main() {
  group('showMeshSheet enableDrag (06-map-bugs.md)', () {
    testWidgets(
      'enableDrag: false lets long-press select sheet text instead of the '
      'gesture being claimed by drag-to-dismiss',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showMeshSheet<void>(
                      context,
                      enableDrag: false,
                      builder: (sheetContext) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: SelectableText(
                          '6f2a9c1b2e3d4f5a6b7c8d9e0f1a2b3c4d5e6f70',
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(SelectableText), findsOneWidget);

        // Long-press a word inside the selectable text — with drag
        // disabled on the sheet, this must produce a text selection
        // (surfaced as the selection toolbar) instead of being swallowed
        // by the sheet's own drag-to-dismiss gesture recognizer.
        await tester.longPress(find.byType(SelectableText));
        await tester.pumpAndSettle();

        expect(find.text('Copy'), findsOneWidget);

        // A vertical drag on the sheet content must not dismiss it.
        await tester.drag(find.byType(SelectableText), const Offset(0, 300));
        await tester.pumpAndSettle();

        expect(find.byType(SelectableText), findsOneWidget);
      },
    );

    testWidgets('enableDrag defaults to true for sheets that do not opt out', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMeshSheet<void>(
                    context,
                    builder: (sheetContext) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Plain sheet'),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Plain sheet'), findsOneWidget);

      await tester.drag(find.text('Plain sheet'), const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.text('Plain sheet'), findsNothing);
    });
  });
}
