import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/utils/contact_search.dart';
import 'package:meshnomad/widgets/dotted_separator.dart';
import 'package:meshnomad/widgets/list_filter_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets(
    'ContactsFilterMenu dropdown uses a dotted separator between groups, '
    'not the native solid PopupMenuDivider (2026-08-29 button-family redesign)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContactsFilterMenu(
            sortOption: ContactSortOption.recentMessages,
            typeFilter: ContactTypeFilter.all,
            showUnreadOnly: false,
            onSortChanged: (_) {},
            onTypeFilterChanged: (_) {},
            onUnreadOnlyChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.filter_list_outlined));
      await tester.pumpAndSettle();

      // Two dotted rules: one between the Sort by / Filters groups, one
      // cutting the "Unread only" toggle off the single-choice rows
      // (variant U-A, 2026-08-29).
      expect(find.byType(DottedSeparator), findsNWidgets(2));
      expect(find.byType(PopupMenuDivider), findsNothing);
      // Generic type param is a private class, so byType<CheckedPopupMenuItem<T>>
      // can't be spelled here — match on the runtime type name instead.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('CheckedPopupMenuItem'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'selected option row is fill-highlighted; the selector dot ghosts '
    'to opacity .30 on unselected options (variant B2, 2026-08-29)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContactsFilterMenu(
            sortOption: ContactSortOption.recentMessages,
            typeFilter: ContactTypeFilter.all,
            showUnreadOnly: false,
            onSortChanged: (_) {},
            onTypeFilterChanged: (_) {},
            onUnreadOnlyChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.filter_list_outlined));
      await tester.pumpAndSettle();

      final selectedText = tester.widget<Text>(find.text('Latest messages'));
      expect(selectedText.style?.fontWeight, FontWeight.w600);

      final unselectedText = tester.widget<Text>(find.text('Heard recently'));
      expect(unselectedText.style?.fontWeight, FontWeight.w500);

      // Every selector dot is wrapped in an Opacity — one option is fully
      // opaque (selected), the rest are ghosted to .30 (unselected).
      final selectedOpacity = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(
        selectedOpacity.any((o) => o.opacity == 1.0),
        isTrue,
        reason: 'the selected option should render a fully opaque dot',
      );
      expect(
        selectedOpacity.any((o) => (o.opacity - 0.30).abs() < 0.001),
        isTrue,
        reason: 'unselected options should render a ghosted (.30) dot',
      );
    },
  );
}
