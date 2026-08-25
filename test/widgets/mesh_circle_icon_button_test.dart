import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: MeshTheme.light().copyWith(
    extensions: const [MeshTokens.defaultTokens],
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('interactive mode renders an IconButton and calls onPressed', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        MeshCircleIconButton(icon: Icons.add, onPressed: () => tapped = true),
      ),
    );

    expect(find.byType(IconButton), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('onPressed:null renders a decorative, non-tappable icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const MeshCircleIconButton(icon: Icons.more_vert, onPressed: null)),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('size and iconSize are honored', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MeshCircleIconButton(
          icon: Icons.remove,
          onPressed: null,
          size: 32,
          iconSize: 15,
        ),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 32);
    expect(sizedBox.height, 32);
  });
}
