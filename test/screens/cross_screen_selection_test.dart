import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for known-issues pkt 2/6-kopiowanie (07-selection-bugs.md):
/// a global `SelectionArea` above the `Navigator` let "select all" sweep up
/// text from OTHER, offstage routes still mounted via
/// `MaterialPageRoute.maintainState` (confirmed root cause, H1, via a throwaway
/// repro during diagnosis — not committed). Every real screen now wraps its
/// own body in `SelectionArea` (`lib/screens/*.dart`); this test proves that
/// pattern in isolation — two routes, each owning its own `SelectionArea`,
/// exactly like production — and asserts "select all" on the current route
/// excludes the previous, offstage route's text.
void main() {
  testWidgets(
    'per-screen SelectionArea: selecting all on the current route excludes '
    "the offstage previous route's text",
    (tester) async {
      String? routeASelection;
      String? routeBSelection;

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: SelectionArea(
            onSelectionChanged: (content) =>
                routeASelection = content?.plainText,
            child: const Scaffold(
              body: Center(child: Text('APP_SETTINGS_STYLE_SECTION_TEXT')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => SelectionArea(
            onSelectionChanged: (content) =>
                routeBSelection = content?.plainText,
            child: const Scaffold(
              body: Center(child: Text('CUSTOM_STYLE_EDITOR_TITLE_TEXT')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Route A (App Settings) is still mounted underneath (maintainState
      // defaults to true) but is a SEPARATE SelectionArea instance now.
      final routeBSelectionArea = tester.widget<SelectionArea>(
        find.byType(SelectionArea).last,
      );
      final routeBState = tester.state<SelectionAreaState>(
        find.byWidget(routeBSelectionArea),
      );
      routeBState.selectableRegion.selectAll();
      await tester.pumpAndSettle();

      expect(routeBSelection, 'CUSTOM_STYLE_EDITOR_TITLE_TEXT');
      expect(routeASelection, isNull);
      expect(
        routeBSelection,
        isNot(contains('APP_SETTINGS_STYLE_SECTION_TEXT')),
      );
    },
  );
}
