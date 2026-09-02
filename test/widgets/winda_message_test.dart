import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_ui.dart';
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
    expect(find.byType(MeshCircleIconButton), findsNothing);
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

  testWidgets(
    'text is clamped to 1 line with ellipsis overflow — a compact "LCD '
    'readout" pill, not a wrapped paragraph (2026-09-02 restyle)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const WindaMessageContent(
            message: WindaMessage(
              text:
                  'A very long message that would need more than one line '
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
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'an action renders a small icon-only MeshCircleIconButton with the '
    'label as its tooltip (not visible text), tapping it calls onAction '
    'exactly once (2026-09-02 restyle: was a full-size FilledButton)',
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

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Resync'), findsNothing);

      final buttonFinder = find.byType(MeshCircleIconButton);
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<MeshCircleIconButton>(buttonFinder);
      expect(button.icon, Icons.refresh);
      // No Tooltip — this widget is hosted above the Navigator (no ancestor
      // Overlay); the label reaches screen readers via Semantics instead.
      expect(button.tooltip, isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Resync',
        ),
        findsOneWidget,
      );

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(tapped, 1);
    },
  );
}
