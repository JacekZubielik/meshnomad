import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/mesh_screen_scaffold.dart';
import 'package:meshnomad/widgets/winda_host_overlay.dart';
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
        TextButton(
          key: const Key('push-page'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MeshScreenScaffold(
                appBar: AppBar(title: const Text('Screen B')),
                body: const Center(child: Text('Screen B body')),
              ),
            ),
          ),
          child: const Text('Push page'),
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

Widget _wrap(Widget child, {WindaHostController? controllerOverride}) {
  final controller = controllerOverride ?? WindaHostController();
  return ChangeNotifierProvider<WindaHostController>.value(
    value: controller,
    child: MaterialApp(
      theme: MeshTheme.light().copyWith(
        extensions: const [MeshTokens.defaultTokens],
      ),
      // Required for MeshScreenScaffold's RouteAware subscription to
      // actually receive didPushNext/didPopNext in this test, exactly as
      // in the real app's main.dart wiring.
      navigatorObservers: [windaRouteObserver],
      builder: (context, navigatorChild) {
        return Stack(
          children: [
            navigatorChild ?? const SizedBox.shrink(),
            const WindaHostOverlay(),
          ],
        );
      },
      home: Scaffold(body: child),
    ),
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
    'a message added while a dialog is open is hit-testable — the real '
    'proof this design exists for, not a semantics-tree existence check',
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

      expect(find.text('A Dialog'), findsOneWidget);
      // hitTestable() is load-bearing here: a widget can be present in the
      // tree (findsOneWidget would pass) while still being visually and
      // interactively buried behind a dialog's modal barrier. Only a
      // hit-testable match proves it is actually reachable/on top — this
      // is exactly the check the previous (reverted) OverlayPortal attempt
      // lacked, which let a broken implementation pass its own test.
      expect(
        find.text('Validation failed while dialog open').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pushing a real second PageRoute on top DOES unregister the message — '
    'the mirror image of the dialog test, proving didPushNext genuinely '
    'fires (and only) for a real page push, not for a dialog',
    (tester) async {
      final controller = WindaHostController();
      await tester.pumpWidget(
        _wrap(const _Harness(), controllerOverride: controller),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-message')));
      await tester.pumpAndSettle();
      expect(find.text('Something happened').hitTestable(), findsOneWidget);
      expect(controller.messages, hasLength(1));

      await tester.tap(find.byKey(const Key('push-page')));
      await tester.pumpAndSettle();

      // Screen B is now on top and is itself a MeshScreenScaffold, so it
      // has no messages of its own — the original screen's message must be
      // gone, not merely obscured, proving didPushNext unregistered it
      // (unlike the dialog case, which must NOT unregister).
      expect(find.text('Screen B body'), findsOneWidget);
      expect(find.text('Something happened'), findsNothing);
      expect(controller.messages, isEmpty);
    },
  );
}
