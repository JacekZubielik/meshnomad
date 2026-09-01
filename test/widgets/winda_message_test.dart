import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/winda_message.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('success tone renders the check icon in MeshTokens.signal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WindaMessageContent(
          message: WindaMessage(
            text: 'Contact added',
            tone: WindaMessageTone.success,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byIcon(Icons.check_circle);
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(iconFinder);
    expect(icon.color, MeshTokens.defaultTokens.signal);
    expect(find.text('Contact added'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('error tone renders the error icon in MeshTokens.alert', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WindaMessageContent(
          message: WindaMessage(
            text: 'Sync failed',
            tone: WindaMessageTone.error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byIcon(Icons.error);
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(iconFinder);
    expect(icon.color, MeshTokens.defaultTokens.alert);
  });

  testWidgets('text is clamped to 2 lines with ellipsis overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WindaMessageContent(
          message: WindaMessage(
            text:
                'A very long message that would need more than two lines '
                'of text to fully display on a narrow phone screen width',
            tone: WindaMessageTone.info,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textWidget = tester.widget<Text>(
      find.textContaining('A very long message'),
    );
    expect(textWidget.maxLines, 2);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'an action renders a FilledButton with the label, tapping it calls '
    'onAction exactly once',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          WindaMessageContent(
            message: WindaMessage(
              text: 'Contact sync stalled',
              tone: WindaMessageTone.error,
              actionLabel: 'Resync',
              onAction: () => tapped++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(FilledButton, 'Resync');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(tapped, 1);
    },
  );
}
