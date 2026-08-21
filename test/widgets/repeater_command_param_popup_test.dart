import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/storage/prefs_manager.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/repeater_command_param_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('commandTemplateHasPlaceholder', () {
    test('true for a command with one or more {...} tokens', () {
      expect(
        commandTemplateHasPlaceholder('set radio {freq},{bw},{sf},{cr}'),
        isTrue,
      );
      expect(commandTemplateHasPlaceholder('set tx {tx-power-dbm}'), isTrue);
      expect(commandTemplateHasPlaceholder('gps {on|off}'), isTrue);
    });

    test('false for a plain command with no placeholder', () {
      expect(commandTemplateHasPlaceholder('ver'), isFalse);
      expect(commandTemplateHasPlaceholder('get radio'), isFalse);
      expect(commandTemplateHasPlaceholder('reboot'), isFalse);
    });
  });

  group('showRepeaterCommandParamPopup', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PrefsManager.reset();
      await PrefsManager.initialize();
    });

    Widget wrap(Widget child) {
      return ChangeNotifierProvider<MeshCoreConnector>(
        create: (_) => MeshCoreConnector(),
        child: MaterialApp(
          theme: MeshTheme.light().copyWith(
            extensions: const [MeshTokens.defaultTokens],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets(
      'a literal {on|off} choice cycles through exactly those two values',
      (tester) async {
        String? sent;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRepeaterCommandParamPopup(
                  context,
                  template: 'gps {on|off}',
                  onSend: (cmd) => sent = cmd,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('on'), findsOneWidget);

        // Tap "+" once: on -> off.
        await tester.tap(find.text('+'));
        await tester.pumpAndSettle();
        expect(find.text('off'), findsOneWidget);

        // Tap "+" again: loops back off -> on.
        await tester.tap(find.text('+'));
        await tester.pumpAndSettle();
        expect(find.text('on'), findsOneWidget);

        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(sent, 'gps on');
      },
    );

    testWidgets(
      'a literal numeric range {1-14} resolves to its default and steps within bounds',
      (tester) async {
        String? sent;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRepeaterCommandParamPopup(
                  context,
                  template: 'set bridge.channel {1-14}',
                  onSend: (cmd) => sent = cmd,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget); // default = range start

        await tester.tap(find.text('+'));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);

        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(sent, 'set bridge.channel 2');
      },
    );

    testWidgets('Cancel closes the popup without sending anything', (
      tester,
    ) async {
      String? sent;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRepeaterCommandParamPopup(
                context,
                template: 'set tx {tx-power-dbm}',
                onSend: (cmd) => sent = cmd,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(sent, isNull);
    });
  });
}
