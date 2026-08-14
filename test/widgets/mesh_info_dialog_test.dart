import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';
import 'package:meshcore_open/widgets/mesh_info_dialog.dart';

Widget _app({required VoidCallback Function(BuildContext) onOpen}) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('small content: dialog wraps it and sits centered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        onOpen: (context) =>
            () => showMeshInfoDialog<void>(
              context,
              title: 'Info',
              builder: (_) => const SizedBox(height: 120, width: 200),
            ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(MaterialApp));
    final dialog = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );

    expect(dialog.height, lessThan(300));
    final topGap = dialog.top - screen.top;
    final bottomGap = screen.bottom - dialog.bottom;
    expect(
      (topGap - bottomGap).abs(),
      lessThanOrEqualTo(1),
      reason:
          'dialog must be vertically centered (top $topGap vs '
          'bottom $bottomGap)',
    );
  });

  testWidgets('large content: dialog caps at the edge inset and scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        onOpen: (context) =>
            () => showMeshInfoDialog<void>(
              context,
              title: 'Info',
              builder: (_) => const SizedBox(height: 5000, width: 200),
            ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(MaterialApp));
    final dialog = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );

    expect(dialog.top - screen.top, MeshInfoDialog.edgeInset);
    expect(screen.bottom - dialog.bottom, MeshInfoDialog.edgeInset);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('close button dismisses the dialog', (tester) async {
    await tester.pumpWidget(
      _app(
        onOpen: (context) =>
            () => showMeshInfoDialog<void>(
              context,
              title: 'Info',
              builder: (_) => const Text('BODY'),
            ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });
}
