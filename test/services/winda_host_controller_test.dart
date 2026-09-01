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
    const messages = [WindaMessage(text: 'Hello', tone: WindaMessageTone.info)];
    controller.register(messages: messages, appBarHeight: 56);

    var notified = 0;
    controller.addListener(() => notified++);
    controller.register(messages: messages, appBarHeight: 56);

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
