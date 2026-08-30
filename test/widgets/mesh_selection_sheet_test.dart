import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_selection_sheet.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

void main() {
  Future<MeshSelectionResult<String?>?>? pendingResult;

  Widget app({String? toggleTitle, bool toggleValue = false}) {
    return MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () {
                pendingResult = showMeshSelectionSheet<String?>(
                  context,
                  title: 'Pick one',
                  options: const [
                    MeshSelectionOption(value: null, label: 'Inherit'),
                    MeshSelectionOption(
                      value: 'a',
                      label: 'Alpha',
                      trailing: 'A',
                    ),
                    MeshSelectionOption(
                      value: 'b',
                      label: 'Beta',
                      trailing: 'B',
                    ),
                  ],
                  selectedValue: 'a',
                  toggleTitle: toggleTitle,
                  toggleValue: toggleValue,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => pendingResult = null);

  testWidgets('winda: Cancel is a bare TextButton, Save a FilledButton; '
      'Cancel returns null (selection discarded)', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Footer button types per the winda template (2026-08-29 user spec).
    expect(
      find.widgetWithText(TextButton, 'Cancel'),
      findsOneWidget,
      reason: 'Cancel must be a bare text button — no fill, no border',
    );
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

    // Change selection, then cancel — nothing should be committed.
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await pendingResult, isNull);
  });

  testWidgets('winda: Save returns the locally selected value and toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(toggleTitle: 'Translate before sending', toggleValue: false),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final r = await pendingResult;
    expect(r, isNotNull);
    expect(r!.value, 'b');
    expect(r.toggleValue, isTrue);
  });

  testWidgets('winda: every row leads with a MeshSelectorDot; the selected '
      'row is the only fully opaque one', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(MeshSelectorDot), findsNWidgets(3));
    final dots = tester.widgetList<MeshSelectorDot>(
      find.byType(MeshSelectorDot),
    );
    expect(dots.where((d) => d.selected).length, 1);
  });
}
