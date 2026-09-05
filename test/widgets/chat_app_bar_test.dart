import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:meshnomad/widgets/chat_app_bar.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

Widget _wrap(Widget home) {
  return ChangeNotifierProvider<MeshCoreConnector>(
    create: (_) => MeshCoreConnector(),
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _Host extends StatelessWidget {
  final VoidCallback? onBack;
  final bool showBottomDivider;
  const _Host({this.onBack, this.showBottomDivider = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: meshChatAppBar(
        context,
        title: const ChatAppBarTitle(name: 'Alice'),
        menuTooltip: 'more',
        menuItemBuilder: (context) => [
          meshMenuActionItem(icon: Icons.delete, label: 'Item A', onTap: () {}),
        ],
        onBack: onBack,
        showBottomDivider: showBottomDivider,
      ),
      body: const Column(
        children: [
          ChatBadgeBar(badges: Text('BADGE')),
          Expanded(child: SizedBox.expand()),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('keeps the theme bottom border by default', (tester) async {
    await tester.pumpWidget(_wrap(const _Host()));
    await tester.pump();
    expect(tester.widget<AppBar>(find.byType(AppBar)).shape, isNull);
  });

  testWidgets('showBottomDivider: false drops the theme bottom border '
      '(for a caller drawing its own accent divider below)', (tester) async {
    await tester.pumpWidget(_wrap(const _Host(showBottomDivider: false)));
    await tester.pump();
    final shape = tester.widget<AppBar>(find.byType(AppBar)).shape;
    expect(shape, isA<Border>());
    expect((shape! as Border).bottom.width, 0);
  });

  testWidgets('back arrow is accent-colored and inside a 48x48 box', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _Host()));
    await tester.pump();

    final arrow = find.byIcon(Icons.arrow_back);
    expect(arrow, findsOneWidget);
    final context = tester.element(arrow);
    final primary = Theme.of(context).colorScheme.primary;
    expect(tester.widget<Icon>(arrow).color, primary);
    final button = find.ancestor(of: arrow, matching: find.byType(IconButton));
    expect(tester.getSize(button), const Size(48, 48));
  });

  testWidgets('back arrow calls onBack when provided', (tester) async {
    var backCalled = 0;
    await tester.pumpWidget(_wrap(_Host(onBack: () => backCalled++)));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(backCalled, 1);
  });

  testWidgets(
    'exactly one menu trigger: the 32/16 circular more_vert, no flat icon',
    (tester) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.pump();

      final circle = find.byWidgetPredicate(
        (w) => w is MeshCircleIconButton && w.icon == Icons.more_vert,
      );
      expect(circle, findsOneWidget);
      final widget = tester.widget<MeshCircleIconButton>(circle);
      expect(widget.size, 32);
      expect(widget.iconSize, 16);
      expect(find.byType(AppBarMenuIcon), findsNothing);
      // The circle sits in a 48x48 box like the back arrow.
      final box = find.ancestor(
        of: circle,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 48 && w.height == 48,
        ),
      );
      expect(box, findsOneWidget);
    },
  );

  testWidgets('menu opens with the schema rows', (tester) async {
    await tester.pumpWidget(_wrap(const _Host()));
    await tester.pump();
    await tester.tap(find.byType(PopupMenuButton<dynamic>));
    await tester.pumpAndSettle();
    expect(find.text('Item A'), findsOneWidget);
    expect(find.byType(MeshMenuActionRow), findsOneWidget);
  });

  testWidgets('title block is horizontally centered on the screen', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _Host()));
    await tester.pump();

    final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
    final name = find.text('Alice');
    expect(name, findsOneWidget);
    expect(tester.getCenter(name).dx, closeTo(screenWidth / 2, 1.0));
    expect(tester.getCenter(name).dy, closeTo(kToolbarHeight / 2, 1.0));
  });

  testWidgets(
    'ChatBadgeBar: the Contacts search-field card, flush under the app bar, '
    'badges centered',
    (tester) async {
      await tester.pumpWidget(_wrap(const _Host()));
      await tester.pump();

      final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
      final bar = find.byType(ChatBadgeBar);
      expect(bar, findsOneWidget);
      expect(tester.getTopLeft(bar).dy, closeTo(kToolbarHeight, 0.5));
      expect(tester.getSize(bar).width, screenWidth);
      final badge = find.text('BADGE');
      expect(tester.getCenter(badge).dx, closeTo(screenWidth / 2, 1.0));

      // Same card contract as Contacts' search field: no own shadow/outline
      // (the MeshCardEdgeShadow in the list Stack casts it), flush edges.
      final card = tester.widget<MeshCard>(
        find.descendant(of: bar, matching: find.byType(MeshCard)),
      );
      expect(card.castsShadow, isFalse);
      expect(card.outlined, isFalse);
      expect(card.radius, 0);
      expect(card.margin, EdgeInsets.zero);
    },
  );

  testWidgets('circular menu edge inset matches the main cards (16dp)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _Host()));
    await tester.pump();
    final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
    final circle = find.byWidgetPredicate(
      (w) => w is MeshCircleIconButton && w.icon == Icons.more_vert,
    );
    expect(screenWidth - tester.getBottomRight(circle).dx, closeTo(16, 0.5));
    // And the back arrow's 24dp icon box sits at the same 16dp from the
    // left edge (its render box is the narrower glyph, so go via center).
    expect(
      tester.getCenter(find.byIcon(Icons.arrow_back)).dx - 12,
      closeTo(16, 0.5),
    );
  });
}
