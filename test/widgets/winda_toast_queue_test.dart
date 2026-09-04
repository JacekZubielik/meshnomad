import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/widgets/winda_message.dart';

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with WindaToastQueue {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [for (final m in toastMessages) Text(m.text)]),
    );
  }
}

void main() {
  testWidgets('pushToast shows the message and drops it after its duration', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));

    state.pushToast(
      const WindaMessage(
        text: 'copied',
        tone: WindaMessageTone.success,
        duration: Duration(seconds: 1),
      ),
    );
    await tester.pump();
    expect(find.text('copied'), findsOneWidget);
    expect(state.toastMessages.length, 1);

    await tester.pump(const Duration(milliseconds: 999));
    expect(find.text('copied'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('copied'), findsNothing);
    expect(state.toastMessages, isEmpty);
  });

  testWidgets('two identical toasts are two entries, dismissed one by one', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));
    const msg = WindaMessage(
      text: 'sent',
      tone: WindaMessageTone.info,
      duration: Duration(seconds: 1),
    );
    state.pushToast(msg);
    await tester.pump(const Duration(milliseconds: 500));
    state.pushToast(msg);
    await tester.pump();
    expect(find.text('sent'), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 501));
    expect(find.text('sent'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('sent'), findsNothing);
  });
}
