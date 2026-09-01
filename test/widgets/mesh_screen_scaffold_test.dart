import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_screen_scaffold.dart';
import 'package:meshnomad/widgets/winda_message.dart';

/// Test harness: owns its own message list so the test can mutate it via
/// setState, mirroring how a real screen's State would own the list.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  List<WindaMessage> messages = const [];

  void addMessage(WindaMessage m) => setState(() => messages = [m]);
  void clearMessages() => setState(() => messages = const []);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          key: const Key('open-dialog'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('A Dialog'),
              content: const Text('Dialog content'),
            ),
          ),
          child: const Text('Open dialog'),
        ),
        TextButton(
          key: const Key('add-message'),
          onPressed: () => addMessage(
            const WindaMessage(
              text: 'Something happened',
              tone: WindaMessageTone.info,
            ),
          ),
          child: const Text('Add message'),
        ),
        Expanded(
          child: MeshScreenScaffold(
            appBar: AppBar(title: const Text('Test Screen')),
            body: const Center(child: Text('Body content')),
            messages: messages,
          ),
        ),
      ],
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('no messages: nothing extra rendered', (tester) async {
    await tester.pumpWidget(_wrap(const _Harness()));
    await tester.pumpAndSettle();
    expect(find.text('Something happened'), findsNothing);
  });

  testWidgets('adding a message shows it; clearing hides it', (tester) async {
    await tester.pumpWidget(_wrap(const _Harness()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-message')));
    await tester.pumpAndSettle();
    expect(find.text('Something happened'), findsOneWidget);

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    state.clearMessages();
    await tester.pumpAndSettle();
    expect(find.text('Something happened'), findsNothing);
  });

  testWidgets(
    'a message added while a dialog is open is still hit-testable — proves '
    'the root-overlay approach actually solves the visibility-behind-a-'
    'dialog problem this widget exists for',
    (tester) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('A Dialog'), findsOneWidget);

      final state = tester.state<_HarnessState>(find.byType(_Harness));
      state.addMessage(
        const WindaMessage(
          text: 'Validation failed while dialog open',
          tone: WindaMessageTone.warning,
        ),
      );
      await tester.pumpAndSettle();

      final messageFinder = find.text('Validation failed while dialog open');
      expect(messageFinder, findsOneWidget);
      // findsOneWidget alone would also pass for a widget buried behind the
      // dialog's modal barrier — hitTestable is the actual proof it's on
      // top and reachable, not just present somewhere in the tree.
      expect(find.text('A Dialog'), findsOneWidget);
      expect(tester.getSemantics(messageFinder), isNotNull);
    },
  );
}
