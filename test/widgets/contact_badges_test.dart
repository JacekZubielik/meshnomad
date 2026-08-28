import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

Widget _wrap(Widget child, {double width = 400}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(
      body: SizedBox(width: width, child: child),
    ),
  );
}

void main() {
  testWidgets('ContactTypeBadge shows the given label and colors by type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ContactTypeBadge(type: advTypeRepeater, label: 'Repeater')),
    );

    expect(find.text('REPEATER'), findsOneWidget);
    final tokens = MeshTokens.defaultTokens;
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border!.top.color, tokens.warn);
  });

  testWidgets('ContactTypeBadge uses a distinct color per node type '
      '(repeater=warn, room=secondary, sensor=signal, chat=primary)', (
    tester,
  ) async {
    final cases = {
      advTypeRepeater: MeshTokens.defaultTokens.warn,
      advTypeRoom: MeshTokens.defaultTokens.roomActive,
      advTypeSensor: MeshTokens.defaultTokens.mapSensor,
      advTypeChat: MeshTokens.defaultTokens.primary,
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(
        _wrap(ContactTypeBadge(type: entry.key, label: 'X')),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.border!.top.color,
        entry.value,
        reason: 'type ${entry.key} should border in ${entry.value}',
      );
    }
  });

  Widget badgeRow({
    bool isFavorite = false,
    bool hasLocation = false,
    bool isSmazEnabled = false,
    String? routeLabel,
    String timeLabel = '~ 1 hour',
    bool isUnread = false,
    double width = 400,
  }) {
    return _wrap(
      ContactBadgeRow(
        isFavorite: isFavorite,
        hasLocation: hasLocation,
        isSmazEnabled: isSmazEnabled,
        routeLabel: routeLabel,
        timeLabel: timeLabel,
        isUnread: isUnread,
      ),
      width: width,
    );
  }

  testWidgets('ContactBadgeRow always renders all 4 badges in fixed order '
      '(GPS, Smaz, Route, Time) plus the right-aligned favorite star, '
      'regardless of state', (tester) async {
    // Wide viewport so all badges land on one line — this test checks
    // left-to-right order, not the Wrap widget's wrapping behavior itself.
    await tester.pumpWidget(badgeRow(routeLabel: null, width: 900));

    final labels = ['GPS', 'SMAZ', 'ROUTE'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('~ 1 HOUR'), findsOneWidget);

    // Fixed order: each label's left edge must be strictly to the right
    // of the previous one's.
    double lastX = -1;
    for (final label in [...labels, '~ 1 HOUR']) {
      final x = tester.getTopLeft(find.text(label)).dx;
      expect(
        x,
        greaterThan(lastX),
        reason: '$label should come after the previous badge',
      );
      lastX = x;
    }

    // Favorite star sits to the right of every badge (2026-08-28: replaced
    // the former FAVORITES badge).
    expect(find.text('FAVORITES'), findsNothing);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(
      tester.getTopLeft(find.byIcon(Icons.star_border)).dx,
      greaterThan(lastX),
    );
  });

  testWidgets('ContactBadgeRow ghosts inactive badges instead of hiding them '
      '(2026-08-19 accepted mockup: position never shifts)', (tester) async {
    await tester.pumpWidget(
      badgeRow(
        isFavorite: true,
        hasLocation: false,
        isSmazEnabled: false,
        routeLabel: 'Flood',
      ),
    );

    Opacity opacityOf(String label) => tester.widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first,
    );

    expect(opacityOf('GPS').opacity, closeTo(0.30, 0.001));
    expect(opacityOf('SMAZ').opacity, closeTo(0.30, 0.001));
    expect(find.text('FLOOD'), findsOneWidget);

    // Favorite star follows the same ghost pattern: filled + full opacity
    // when favorite, outlined + 0.30 when not.
    Opacity starOpacity(IconData icon) => tester.widget<Opacity>(
      find
          .ancestor(of: find.byIcon(icon), matching: find.byType(Opacity))
          .first,
    );
    expect(starOpacity(Icons.star).opacity, 1.0);

    await tester.pumpWidget(badgeRow(isFavorite: false, routeLabel: 'Flood'));
    expect(starOpacity(Icons.star_border).opacity, closeTo(0.30, 0.001));
  });

  testWidgets(
    'ContactBadgeRow shows a ghosted "ROUTE" placeholder when routeLabel is null',
    (tester) async {
      await tester.pumpWidget(badgeRow(routeLabel: null));
      expect(find.text('ROUTE'), findsOneWidget);
    },
  );

  testWidgets(
    'ContactBadgeRow colors the Time badge primary when unread, '
    'onSurfaceVariant otherwise (matches pre-existing last-seen text behavior)',
    (tester) async {
      await tester.pumpWidget(badgeRow(isUnread: true));
      var text = tester.widget<Text>(find.text('~ 1 HOUR'));
      expect(text.style?.color, MeshTokens.defaultTokens.primary);

      await tester.pumpWidget(badgeRow(isUnread: false));
      text = tester.widget<Text>(find.text('~ 1 HOUR'));
      expect(text.style?.color, MeshTheme.light().colorScheme.onSurfaceVariant);
    },
  );

  testWidgets(
    'ContactBadgeRow renders the Route badge with a filled background '
    'when active, and no fill when ghosted (2026-08-19 refinement)',
    (tester) async {
      await tester.pumpWidget(badgeRow(routeLabel: '3 hops'));
      final activeContainer = tester.widget<Container>(
        find
            .ancestor(of: find.text('3 HOPS'), matching: find.byType(Container))
            .first,
      );
      final activeDecoration = activeContainer.decoration as BoxDecoration;
      expect(
        activeDecoration.color,
        MeshTokens.defaultTokens.routeActive.withValues(alpha: 0.2),
      );
      expect(
        activeDecoration.border!.top.color,
        MeshTokens.defaultTokens.routeActive,
      );

      await tester.pumpWidget(badgeRow(routeLabel: null));
      final ghostContainer = tester.widget<Container>(
        find
            .ancestor(of: find.text('ROUTE'), matching: find.byType(Container))
            .first,
      );
      final ghostDecoration = ghostContainer.decoration as BoxDecoration;
      expect(ghostDecoration.color, isNull);
      expect(
        ghostDecoration.border!.top.color,
        MeshTokens.defaultTokens.routeActive,
      );
    },
  );

  testWidgets('ContactBadgeRow badge interactivity: Favorite always tappable, '
      'GPS/Route only tappable when active (2026-08-19 refinement)', (
    tester,
  ) async {
    var favoriteTaps = 0;
    var gpsTaps = 0;
    var routeTaps = 0;
    Widget interactiveRow({bool hasLocation = false, String? routeLabel}) {
      return _wrap(
        ContactBadgeRow(
          isFavorite: false,
          hasLocation: hasLocation,
          isSmazEnabled: false,
          routeLabel: routeLabel,
          timeLabel: '~ 1 hour',
          isUnread: false,
          onFavoriteTap: () => favoriteTaps++,
          onGpsTap: () => gpsTaps++,
          onRouteTap: () => routeTaps++,
        ),
        width: 900,
      );
    }

    // Everything inactive: the favorite star still fires (2026-08-28:
    // replaced the FAVORITES badge, same always-tappable semantics),
    // GPS/Route do not.
    await tester.pumpWidget(interactiveRow());
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.tap(find.text('GPS'));
    await tester.tap(find.text('ROUTE'));
    await tester.pump();
    expect(favoriteTaps, 1);
    expect(gpsTaps, 0);
    expect(routeTaps, 0);

    // Active GPS/Route: both now fire.
    await tester.pumpWidget(
      interactiveRow(hasLocation: true, routeLabel: '2 hops'),
    );
    await tester.tap(find.text('GPS'));
    await tester.tap(find.text('2 HOPS'));
    await tester.pump();
    expect(gpsTaps, 1);
    expect(routeTaps, 1);
  });
}
