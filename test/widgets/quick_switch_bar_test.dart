import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/quick_switch_bar.dart';

// M3 navigation indicator pill height (NavigationBar spec).
const double _indicatorHeight = 32.0;

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

  testWidgets('pill and labels fit inside the bar with balanced margins', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        QuickSwitchBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          contactsUnreadCount: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(NavigationBar));

    // The selected destination's icon sits centered inside the indicator
    // pill, so the pill's top edge is half the pill height above the icon
    // center.
    final iconRect = tester.getRect(find.byIcon(Icons.people).first);
    final pillTop = iconRect.center.dy - _indicatorHeight / 2;
    final pillTopMargin = pillTop - barRect.top;

    final labelRect = tester.getRect(find.text('Contacts').first);
    final labelBottomMargin = barRect.bottom - labelRect.bottom;

    expect(
      pillTopMargin,
      greaterThanOrEqualTo(6),
      reason:
          'indicator pill must keep a visible margin from the top of the '
          'bar (top margin $pillTopMargin)',
    );
    expect(
      labelBottomMargin,
      greaterThanOrEqualTo(6),
      reason:
          'label must keep a visible margin from the bottom of the bar '
          '(bottom margin $labelBottomMargin)',
    );
    expect(
      (pillTopMargin - labelBottomMargin).abs(),
      lessThanOrEqualTo(8),
      reason:
          'top and bottom margins must be proportional '
          '(top $pillTopMargin vs bottom $labelBottomMargin)',
    );

    // The unread badge rides above the icon — it must stay inside the bar.
    final badgeRect = tester.getRect(find.text('3'));
    expect(
      badgeRect.top,
      greaterThanOrEqualTo(barRect.top),
      reason:
          'unread badge must not be clipped by the top of the bar '
          '(badge top ${badgeRect.top} vs bar top ${barRect.top})',
    );
  });

  testWidgets('labels still fit with a larger system text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      _wrap(QuickSwitchBar(selectedIndex: 0, onDestinationSelected: (_) {})),
    );
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(NavigationBar));
    final labelRect = tester.getRect(find.text('Contacts').first);
    expect(
      barRect.bottom - labelRect.bottom,
      greaterThanOrEqualTo(2),
      reason: 'label must not overflow the bar at 1.3x text scale',
    );
  });
}
