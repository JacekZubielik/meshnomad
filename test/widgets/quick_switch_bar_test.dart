import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/quick_switch_bar.dart';

Widget _wrap(Widget bar) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: SafeArea(top: false, child: bar),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders 3 icon-only destinations — active as FilledButton, '
      'inactive as OutlinedButton, no text captions (2026-08-29 redesign)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(QuickSwitchBar(selectedIndex: 0, onDestinationSelected: (_) {})),
    );
    await tester.pumpAndSettle();

    // Chip pattern from the QuickStylePicker: selected = FilledButton,
    // the other two = OutlinedButton.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(find.byType(NavigationBar), findsNothing);

    // Selected slot shows the filled icon variant, others outlined.
    expect(find.byIcon(Icons.people), findsOneWidget);
    expect(find.byIcon(Icons.tag), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);

    // Icons only — screen names must NOT render as visible captions.
    expect(find.text('Contacts'), findsNothing);
    expect(find.text('Channels'), findsNothing);
    expect(find.text('Map'), findsNothing);
  });

  testWidgets('active button lives inside the FilledButton slot matching '
      'selectedIndex', (tester) async {
    await tester.pumpWidget(
      _wrap(QuickSwitchBar(selectedIndex: 2, onDestinationSelected: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byIcon(Icons.map),
      ),
      findsOneWidget,
    );
  });

  testWidgets('taps report the destination index without changing '
      'own state (behavior identical to the old NavigationBar)', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      _wrap(QuickSwitchBar(selectedIndex: 0, onDestinationSelected: taps.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tag));
    await tester.tap(find.byIcon(Icons.map_outlined));
    // Active destination also stays tappable.
    await tester.tap(find.byIcon(Icons.people));
    await tester.pump();

    expect(taps, [1, 2, 0]);
  });

  testWidgets('unread badges ride on the contacts and channels icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        QuickSwitchBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          contactsUnreadCount: 3,
          channelsUnreadCount: 120,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('destinations keep semantic labels for assistive tech '
      'even without visible captions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(QuickSwitchBar(selectedIndex: 0, onDestinationSelected: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Contacts'), findsOneWidget);
    expect(find.bySemanticsLabel('Channels'), findsOneWidget);
    expect(find.bySemanticsLabel('Map'), findsOneWidget);
    handle.dispose();
  });
}
