import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/message.dart';
import 'package:meshcore_open/models/channel_message.dart';
import 'package:meshcore_open/storage/message_store.dart';
import 'package:meshcore_open/storage/channel_message_store.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to create a test message
Message _makeMessage({
  int index = 0,
  bool isOutgoing = true,
  DateTime? timestamp,
}) {
  return Message(
    senderKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    text: 'Test message $index',
    timestamp: timestamp ?? DateTime.now().add(Duration(minutes: index)),
    isOutgoing: isOutgoing,
    isCli: false,
    status: MessageStatus.sent,
  );
}

/// Helper to create a test channel message
ChannelMessage _makeChannelMessage({int index = 0, DateTime? timestamp}) {
  return ChannelMessage(
    senderKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    senderName: 'TestUser',
    text: 'Channel message $index',
    timestamp: timestamp ?? DateTime.now().add(Duration(minutes: index)),
    isOutgoing: true,
    status: ChannelMessageStatus.sent,
    channelIndex: 0,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsManager.initialize();
  });

  group('MessageStore history cap', () {
    test('Limit 3, save 5 messages → keeps 3 newest', () async {
      final store = MessageStore();
      store.setPublicKeyHex = 'abc123def456';

      // Create 5 messages with increasing timestamps
      final messages = List.generate(5, (i) => _makeMessage(index: i));

      // Save with limit of 3
      await store.saveMessages('contact1', messages, historyLimit: 3);

      // Load back
      final loaded = await store.loadMessages('contact1');

      // Should have 3 messages (the newest ones, indices 2, 3, 4)
      expect(loaded.length, equals(3));
      expect(loaded[0].text, equals('Test message 2'));
      expect(loaded[1].text, equals('Test message 3'));
      expect(loaded[2].text, equals('Test message 4'));
    });

    test('Limit 0 (unlimited) → no trimming', () async {
      final store = MessageStore();
      store.setPublicKeyHex = 'abc123def456';

      final messages = List.generate(5, (i) => _makeMessage(index: i));

      // Save with limit of 0 (no limit)
      await store.saveMessages('contact2', messages, historyLimit: 0);

      final loaded = await store.loadMessages('contact2');

      // Should have all 5 messages
      expect(loaded.length, equals(5));
    });

    test(
      'Existing blob with 5 messages, limit 3, add 1 → 3 newest after save',
      () async {
        final store = MessageStore();
        store.setPublicKeyHex = 'abc123def456';

        // First, save 5 messages without limit
        final initial5 = List.generate(5, (i) => _makeMessage(index: i));
        await store.saveMessages('contact3', initial5, historyLimit: 0);

        // Verify we have 5
        var loaded = await store.loadMessages('contact3');
        expect(loaded.length, equals(5));

        // Now load, add one new message, and save with limit of 3
        loaded = await store.loadMessages('contact3');
        final newMsg = _makeMessage(index: 5);
        loaded.add(newMsg);

        await store.saveMessages('contact3', loaded, historyLimit: 3);

        // Load again: should have 3 newest (indices 3, 4, 5)
        loaded = await store.loadMessages('contact3');
        expect(loaded.length, equals(3));
        expect(loaded[0].text, equals('Test message 3'));
        expect(loaded[1].text, equals('Test message 4'));
        expect(loaded[2].text, equals('Test message 5'));
      },
    );
  });

  group('ChannelMessageStore history cap', () {
    test('Limit 3, save 5 channel messages → keeps 3 newest', () async {
      final store = ChannelMessageStore();
      store.setPublicKeyHex = 'abc123def456';

      final messages = List.generate(5, (i) => _makeChannelMessage(index: i));

      await store.saveChannelMessages(0, messages, historyLimit: 3);

      final loaded = await store.loadChannelMessages(0);

      expect(loaded.length, equals(3));
      expect(loaded[0].text, equals('Channel message 2'));
      expect(loaded[1].text, equals('Channel message 3'));
      expect(loaded[2].text, equals('Channel message 4'));
    });

    test('Limit 0 (unlimited) → no trimming', () async {
      final store = ChannelMessageStore();
      store.setPublicKeyHex = 'abc123def456';

      final messages = List.generate(5, (i) => _makeChannelMessage(index: i));

      await store.saveChannelMessages(1, messages, historyLimit: 0);

      final loaded = await store.loadChannelMessages(1);

      expect(loaded.length, equals(5));
    });

    test(
      'Existing blob with 5 channel messages, limit 3, add 1 → 3 newest after save',
      () async {
        final store = ChannelMessageStore();
        store.setPublicKeyHex = 'abc123def456';

        final initial5 = List.generate(5, (i) => _makeChannelMessage(index: i));
        await store.saveChannelMessages(2, initial5, historyLimit: 0);

        var loaded = await store.loadChannelMessages(2);
        expect(loaded.length, equals(5));

        loaded = await store.loadChannelMessages(2);
        final newMsg = _makeChannelMessage(index: 5);
        loaded.add(newMsg);

        await store.saveChannelMessages(2, loaded, historyLimit: 3);

        loaded = await store.loadChannelMessages(2);
        expect(loaded.length, equals(3));
        expect(loaded[0].text, equals('Channel message 3'));
        expect(loaded[1].text, equals('Channel message 4'));
        expect(loaded[2].text, equals('Channel message 5'));
      },
    );
  });
}
