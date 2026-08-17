import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/path_history.dart';
import 'package:meshcore_open/services/storage_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

ContactPathHistory _history(String contactPubKeyHex, {int hopCount = 1}) {
  return ContactPathHistory(
    contactPubKeyHex: contactPubKeyHex,
    recentPaths: [
      PathRecord(
        hopCount: hopCount,
        tripTimeMs: 1000,
        timestamp: DateTime(2026, 1, 1),
        wasFloodDiscovery: false,
        pathBytes: const [1, 2],
        successCount: 1,
        failureCount: 0,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
  });

  group('device-scoped path history', () {
    test('two devices do not collide for the same contact key', () async {
      final storage = StorageService();
      const contactHex = 'contact-abc';

      storage.setPublicKeyHex = 'aaaaaaaaaaaaaaaaaaaa';
      await storage.savePathHistory(
        contactHex,
        _history(contactHex, hopCount: 1),
      );

      storage.setPublicKeyHex = 'bbbbbbbbbbbbbbbbbbbb';
      await storage.savePathHistory(
        contactHex,
        _history(contactHex, hopCount: 2),
      );

      storage.setPublicKeyHex = 'aaaaaaaaaaaaaaaaaaaa';
      final loaded = await storage.loadPathHistory(contactHex);

      expect(loaded!.recentPaths.single.hopCount, 1);
    });

    test('clearAllPathHistories only clears the active device scope', () async {
      final storage = StorageService();
      const contactHex = 'contact-abc';

      storage.setPublicKeyHex = 'aaaaaaaaaaaaaaaaaaaa';
      await storage.savePathHistory(contactHex, _history(contactHex));

      storage.setPublicKeyHex = 'bbbbbbbbbbbbbbbbbbbb';
      await storage.savePathHistory(contactHex, _history(contactHex));

      await storage.clearAllPathHistories();
      expect(await storage.loadPathHistory(contactHex), isNull);

      storage.setPublicKeyHex = 'aaaaaaaaaaaaaaaaaaaa';
      expect(await storage.loadPathHistory(contactHex), isNotNull);
    });
  });

  group('legacy unscoped key migration', () {
    test(
      'loadPathHistory migrates a pre-existing unscoped entry to the device-scoped key',
      () async {
        const contactHex = 'contact-abc';
        final legacyHistory = _history(contactHex, hopCount: 3);
        final prefs = PrefsManager.instance;
        await prefs.setString(
          'path_history_$contactHex',
          jsonEncode(legacyHistory.toJson()),
        );

        final storage = StorageService();
        storage.setPublicKeyHex = 'aaaaaaaaaaaaaaaaaaaa';
        final loaded = await storage.loadPathHistory(contactHex);

        expect(loaded, isNotNull);
        expect(loaded!.recentPaths.single.hopCount, 3);
        expect(prefs.getString('path_history_$contactHex'), isNull);
      },
    );
  });
}
