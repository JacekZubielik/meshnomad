import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/repeater_command_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
  });

  Widget wrap(Widget child) {
    // The parameter popup (opened for placeholder commands) reads
    // MeshCoreConnector.maxTxPower via Provider — every test needs one in
    // scope even if it never opens that popup.
    return ChangeNotifierProvider<MeshCoreConnector>(
      create: (_) => MeshCoreConnector(),
      child: MaterialApp(
        theme: MeshTheme.light().copyWith(
          extensions: const [MeshTokens.defaultTokens],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('opens and shows the command drawer header', (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => RepeaterCommandDrawer.show(
              context,
              onCommandSelected: (cmd) => selected = cmd,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // RepeaterCommandDrawer is a static helper (its `show()` pushes a
    // private StatefulWidget), never a type in the tree — assert on real
    // header content instead of `find.byType(RepeaterCommandDrawer)`, which
    // would find nothing whether or not the drawer actually opened.
    expect(find.textContaining('COMMANDS LIST'), findsOneWidget);
    expect(selected, isNull);
  });

  testWidgets(
    'tapping a plain command chip sends it immediately and keeps the drawer open',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RepeaterCommandDrawer.show(
                context,
                onCommandSelected: (cmd) => selected = cmd,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Info'), findsWidgets); // jumpbar chip + group title
      expect(find.text('ver'), findsOneWidget);

      await tester.tap(find.text('ver'));
      await tester.pumpAndSettle();

      expect(selected, 'ver');
      // No placeholder in "ver" — sent straight away, drawer stays open so
      // the response appears below without dismissing the command list.
      expect(find.text('ver'), findsOneWidget);
      expect(find.textContaining('COMMANDS LIST'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a chip with a placeholder opens the parameter popup instead of sending',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RepeaterCommandDrawer.show(
                context,
                onCommandSelected: (cmd) => selected = cmd,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final radioJumpChip = find.widgetWithText(ActionChip, 'Radio');
      await tester.tap(radioJumpChip);
      await tester.pumpAndSettle();

      final setRadioChip = find.textContaining('set radio {freq}');
      expect(setRadioChip, findsOneWidget);
      await tester.tap(setRadioChip);
      await tester.pumpAndSettle();

      // Popup opened, nothing sent yet, drawer still there underneath.
      expect(selected, isNull);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.textContaining('COMMANDS LIST'), findsOneWidget);

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Resolved with the field defaults — a fully substituted command,
      // no literal "{...}" left in it.
      expect(selected, isNotNull);
      expect(selected, isNot(contains('{')));
      expect(selected, startsWith('set radio '));
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets('tapping a jumpbar group actually scrolls the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                RepeaterCommandDrawer.show(context, onCommandSelected: (_) {}),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const Key('repeaterCommandDrawerContentScroll')),
      matching: find.byType(Scrollable),
    );
    final initialOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;

    // Regression guard for the bug where Scrollable.ensureVisible() no-ops
    // once a group is even partially onscreen: with dense chip rows several
    // groups can be simultaneously visible, so only the very first group
    // ("Info") ever produced a real scroll. Jumping to a later group must
    // move the list a meaningful, non-zero amount.
    final adminJumpChip = find.widgetWithText(ActionChip, 'Admin');
    expect(adminJumpChip, findsOneWidget);
    await tester.tap(adminJumpChip);
    await tester.pumpAndSettle();

    final afterAdminOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(afterAdminOffset, greaterThan(initialOffset + 100));

    // Jumping back to "Info" must scroll up again, not just append/no-op.
    final infoJumpChip = find.widgetWithText(ActionChip, 'Info');
    await tester.tap(infoJumpChip);
    await tester.pumpAndSettle();

    final afterInfoOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(afterInfoOffset, lessThan(afterAdminOffset));
  });
}
