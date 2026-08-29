// Regression tests for TranslationService.shouldTranslateOutgoing's
// additionalOptIn parameter, added 2026-08-29 so a per-conversation
// translate-before-sending toggle can enable outgoing translation without
// requiring the app-wide composer switch to be on.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/services/translation_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';

void main() {
  late AppSettingsService settingsService;
  late TranslationService translationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    settingsService = AppSettingsService();
    await settingsService.loadSettings();
    translationService = TranslationService(settingsService);
  });

  group('shouldTranslateOutgoing — additionalOptIn', () {
    test(
      'global composer OFF, additionalOptIn OFF → does not translate',
      () async {
        await settingsService.setComposerTranslationEnabled(false);
        expect(
          translationService.shouldTranslateOutgoing(
            text: 'hello there',
            targetLanguageCode: 'de',
          ),
          isFalse,
        );
      },
    );

    test(
      'global composer OFF, per-conversation additionalOptIn ON → translates',
      () async {
        await settingsService.setComposerTranslationEnabled(false);
        expect(
          translationService.shouldTranslateOutgoing(
            text: 'hello there',
            targetLanguageCode: 'de',
            additionalOptIn: true,
          ),
          isTrue,
        );
      },
    );

    test(
      'global composer ON → translates regardless of additionalOptIn',
      () async {
        await settingsService.setComposerTranslationEnabled(true);
        expect(
          translationService.shouldTranslateOutgoing(
            text: 'hello there',
            targetLanguageCode: 'de',
          ),
          isTrue,
        );
      },
    );

    test(
      'additionalOptIn ON but no target language → does not translate',
      () async {
        await settingsService.setComposerTranslationEnabled(false);
        expect(
          translationService.shouldTranslateOutgoing(
            text: 'hello there',
            targetLanguageCode: null,
            additionalOptIn: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'additionalOptIn ON but text not plain-eligible → does not translate',
      () async {
        await settingsService.setComposerTranslationEnabled(false);
        expect(
          translationService.shouldTranslateOutgoing(
            text: 'm:somepayload',
            targetLanguageCode: 'de',
            additionalOptIn: true,
          ),
          isFalse,
        );
      },
    );
  });
}
