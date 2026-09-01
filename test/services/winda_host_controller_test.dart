import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/services/winda_host_controller.dart';
import 'package:meshnomad/widgets/winda_message.dart';

void main() {
  test('starts empty', () {
    final controller = WindaHostController();
    expect(controller.messages, isEmpty);
    expect(controller.appBarHeight, 0);
  });

  test('register sets messages and appBarHeight, notifies listeners', () {
    final controller = WindaHostController();
    var notified = 0;
    controller.addListener(() => notified++);

    controller.register(
      messages: const [
        WindaMessage(text: 'Hello', tone: WindaMessageTone.info),
      ],
      appBarHeight: 56,
    );

    expect(controller.messages, hasLength(1));
    expect(controller.messages.first.text, 'Hello');
    expect(controller.appBarHeight, 56);
    expect(notified, 1);
  });

  test('register with identical values is a no-op — does not notify', () {
    final controller = WindaHostController();
    // Deliberately two SEPARATE (non-const, non-identical) WindaMessage/list
    // instances that are only value-equal — this is what a real screen does
    // when it rebuilds a fresh WindaMessage from a runtime l10n string every
    // frame (Task 5). Without WindaMessage.== this test would only pass by
    // accident (identical() short-circuit / const canonicalization), not
    // because listEquals actually did a value comparison.
    controller.register(
      messages: List<WindaMessage>.from([
        WindaMessage(text: 'Hello', tone: WindaMessageTone.info),
      ]),
      appBarHeight: 56,
    );

    var notified = 0;
    controller.addListener(() => notified++);
    controller.register(
      messages: List<WindaMessage>.from([
        WindaMessage(text: 'Hello', tone: WindaMessageTone.info),
      ]),
      appBarHeight: 56,
    );

    expect(notified, 0);
  });

  test('unregister clears messages and notifies', () {
    final controller = WindaHostController();
    controller.register(
      messages: const [
        WindaMessage(text: 'Hello', tone: WindaMessageTone.info),
      ],
      appBarHeight: 56,
    );

    var notified = 0;
    controller.addListener(() => notified++);
    controller.unregister();

    expect(controller.messages, isEmpty);
    expect(notified, 1);
  });

  test('unregister when already empty is a no-op — does not notify', () {
    final controller = WindaHostController();
    var notified = 0;
    controller.addListener(() => notified++);
    controller.unregister();
    expect(notified, 0);
  });
}
