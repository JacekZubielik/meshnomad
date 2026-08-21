import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/utils/emoji_utils.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

BoxDecoration _circleDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(AvatarCircle),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration as BoxDecoration;
}

void main() {
  testWidgets('AvatarCircle renders emoji as content while keeping the '
      'fixed-color decoration (2026-08-21 fix)', (tester) async {
    final tokens = MeshTokens.defaultTokens;
    await tester.pumpWidget(
      _wrap(
        AvatarCircle(name: '🏠 Room', color: tokens.roomActive, emoji: '🏠'),
      ),
    );

    expect(find.text('🏠'), findsOneWidget);
    final decoration = _circleDecoration(tester);
    expect(decoration.color, tokens.roomActive.withValues(alpha: 0.14));
    expect(
      decoration.border!.top.color,
      tokens.roomActive.withValues(alpha: 0.4),
    );
  });

  testWidgets('AvatarCircle per-name tint ignores emoji in the name, so an '
      'emoji never shifts a chat avatar\'s background/border', (tester) async {
    await tester.pumpWidget(_wrap(const AvatarCircle(name: 'Alice')));
    final plain = _circleDecoration(tester);

    await tester.pumpWidget(
      _wrap(const AvatarCircle(name: '🦊 Alice', emoji: '🦊')),
    );
    final withEmoji = _circleDecoration(tester);

    expect(withEmoji.color, plain.color);
    expect(withEmoji.border!.top.color, plain.border!.top.color);
  });

  test('stripEmoji removes emoji clusters and trims edges', () {
    expect(stripEmoji('🦊 Alice'), 'Alice');
    expect(stripEmoji('Alice 🦊 Bob'), 'Alice  Bob');
    expect(stripEmoji('Alice'), 'Alice');
  });
}
