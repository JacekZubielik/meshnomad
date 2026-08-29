// Regression tests for wiring per-conversation (per-contact/per-channel)
// translation language overrides into MeshCoreConnector's incoming
// translation pipeline (2026-08-29). Before this change,
// translateContactMessage/translateChannelMessage only ever consulted the
// app-wide language chain — a per-conversation override set via
// setContactTranslation/setChannelTranslation was silently ignored.
//
// A fake TranslationService subclass intercepts translateIncomingText to
// capture the targetLanguageCode it was actually called with, avoiding any
// dependency on the real on-device llama translation engine/model.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/connector/meshcore_protocol.dart';
import 'package:meshnomad/models/channel_message.dart';
import 'package:meshnomad/models/message.dart';
import 'package:meshnomad/models/translation_support.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';

class _FakeTranslationService extends TranslationService {
  _FakeTranslationService(super.appSettingsService);

  String? lastTargetLanguageCode;
  int callCount = 0;

  @override
  Future<TranslationResult?> translateIncomingText({
    required String text,
    required String? targetLanguageCode,
  }) async {
    callCount++;
    lastTargetLanguageCode = targetLanguageCode;
    return TranslationResult(
      translatedText: 'FAKE: $text',
      targetLanguageCode: targetLanguageCode ?? 'en',
      status: MessageTranslationStatus.completed,
    );
  }
}

Message _makeIncomingMessage({
  required Uint8List senderKey,
  String text = 'hello',
}) {
  return Message(
    senderKey: senderKey,
    text: text,
    timestamp: DateTime.now(),
    isOutgoing: false,
    isCli: false,
    status: MessageStatus.delivered,
  );
}

ChannelMessage _makeIncomingChannelMessage({
  required int channelIndex,
  String text = 'hello channel',
}) {
  return ChannelMessage(
    senderKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    senderName: 'TestUser',
    text: text,
    timestamp: DateTime.now(),
    isOutgoing: false,
    status: ChannelMessageStatus.sent,
    channelIndex: channelIndex,
  );
}

void main() {
  late AppSettingsService settingsService;
  late _FakeTranslationService translationService;
  late MeshCoreConnector connector;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    settingsService = AppSettingsService();
    await settingsService.loadSettings();
    await settingsService.setTranslationEnabled(true);
    translationService = _FakeTranslationService(settingsService);
    connector = MeshCoreConnector();
    connector.debugAppSettingsService = settingsService;
    connector.debugTranslationService = translationService;
  });

  group('translateContactMessage — per-contact language override', () {
    test('contact override "de" is passed to translateIncomingText', () async {
      final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
      final contactKeyHex = pubKeyToHex(senderKey);
      await connector.setContactTranslation(
        contactKeyHex,
        languageCode: 'de',
        translateBeforeSending: false,
      );

      final message = _makeIncomingMessage(senderKey: senderKey);
      final result = await connector.translateContactMessage(
        contactKeyHex,
        message,
        manualTranslation: true,
      );

      expect(result, isNotNull);
      expect(translationService.lastTargetLanguageCode, 'de');
    });

    test(
      'no contact override falls back to the app-wide language chain',
      () async {
        await settingsService.setLanguageOverride('pl');
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final contactKeyHex = pubKeyToHex(senderKey);

        final message = _makeIncomingMessage(senderKey: senderKey);
        final result = await connector.translateContactMessage(
          contactKeyHex,
          message,
          manualTranslation: true,
        );

        expect(result, isNotNull);
        expect(translationService.lastTargetLanguageCode, 'pl');
      },
    );

    test(
      'whitespace-only contact override is treated as unset and falls back',
      () async {
        await settingsService.setLanguageOverride('pl');
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final contactKeyHex = pubKeyToHex(senderKey);
        await connector.setContactTranslation(
          contactKeyHex,
          languageCode: '   ',
          translateBeforeSending: false,
        );

        final message = _makeIncomingMessage(senderKey: senderKey);
        final result = await connector.translateContactMessage(
          contactKeyHex,
          message,
          manualTranslation: true,
        );

        expect(result, isNotNull);
        expect(translationService.lastTargetLanguageCode, 'pl');
      },
    );
  });

  group('translateChannelMessage — per-channel language override', () {
    test('channel override "de" is passed to translateIncomingText', () async {
      const channelIndex = 3;
      await connector.setChannelTranslation(
        channelIndex,
        languageCode: 'de',
        translateBeforeSending: false,
      );

      final message = _makeIncomingChannelMessage(channelIndex: channelIndex);
      final result = await connector.translateChannelMessage(
        channelIndex,
        message,
        manualTranslation: true,
      );

      expect(result, isNotNull);
      expect(translationService.lastTargetLanguageCode, 'de');
    });

    test(
      'no channel override falls back to the app-wide language chain',
      () async {
        await settingsService.setLanguageOverride('pl');
        const channelIndex = 4;

        final message = _makeIncomingChannelMessage(channelIndex: channelIndex);
        final result = await connector.translateChannelMessage(
          channelIndex,
          message,
          manualTranslation: true,
        );

        expect(result, isNotNull);
        expect(translationService.lastTargetLanguageCode, 'pl');
      },
    );
  });
}
