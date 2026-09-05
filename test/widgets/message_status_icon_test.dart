import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/message_status_icon.dart';

Future<void> _pump(WidgetTester tester, MessageStatusIcon icon) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: icon)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('delivered → Material double tick in the signal tint '
      '(2026-09-05: replaced the bundled done_all.svg)', (tester) async {
    await _pump(tester, const MessageStatusIcon(isAcked: true));
    final icon = tester.widget<Icon>(find.byIcon(Icons.done_all));
    final t = MeshTokens.of(tester.element(find.byType(MessageStatusIcon)));
    expect(icon.color, t.signal.withValues(alpha: 0.9));
    expect(find.byIcon(Icons.done), findsNothing);
  });

  testWidgets('heard repeated → the same double tick', (tester) async {
    await _pump(
      tester,
      const MessageStatusIcon(isAcked: false, isRepeated: true),
    );
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('sent without ack → single tick in the caller tint', (
    tester,
  ) async {
    await _pump(
      tester,
      const MessageStatusIcon(isAcked: false, onColor: Colors.purple),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.done));
    expect(icon.color, Colors.purple);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('failed → error cross', (tester) async {
    await _pump(
      tester,
      const MessageStatusIcon(isAcked: false, isFailed: true),
    );
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });
}
