import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/path_history.dart';
import 'package:meshcore_open/services/secure_key_value_store.dart';
import 'package:meshcore_open/services/storage_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// In-memory fake — no platform channels, so repeater-password tests don't
// need to mock flutter_secure_storage's MethodChannel.
class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);
}

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

  group('repeater passwords — encrypted at rest', () {
    test('save + get round-trips through secure storage', () async {
      final secure = FakeSecureKeyValueStore();
      final storage = StorageService(secureStorage: secure);

      await storage.saveRepeaterPassword('repeater-abc', 'hunter2');

      expect(await storage.getRepeaterPassword('repeater-abc'), 'hunter2');
      // Not sitting anywhere in plaintext SharedPreferences.
      expect(PrefsManager.instance.getString('repeater_passwords'), isNull);
    });

    test('getRepeaterPassword returns null when nothing is saved', () async {
      final storage = StorageService(secureStorage: FakeSecureKeyValueStore());

      expect(await storage.getRepeaterPassword('repeater-abc'), isNull);
    });

    test('removeRepeaterPassword deletes it', () async {
      final secure = FakeSecureKeyValueStore();
      final storage = StorageService(secureStorage: secure);
      await storage.saveRepeaterPassword('repeater-abc', 'hunter2');

      await storage.removeRepeaterPassword('repeater-abc');

      expect(await storage.getRepeaterPassword('repeater-abc'), isNull);
    });

    test(
      'is not scoped by device — the same repeater password is visible regardless of publicKeyHex',
      () async {
        final storage = StorageService(
          secureStorage: FakeSecureKeyValueStore(),
        );

        storage.setPublicKeyHex = 'aaaaaaaaaaaaaaaaaaaa';
        await storage.saveRepeaterPassword('repeater-abc', 'hunter2');

        storage.setPublicKeyHex = 'bbbbbbbbbbbbbbbbbbbb';
        expect(await storage.getRepeaterPassword('repeater-abc'), 'hunter2');
      },
    );

    test(
      'clearAllRepeaterPasswords clears only repeater-password entries',
      () async {
        final secure = FakeSecureKeyValueStore();
        final storage = StorageService(secureStorage: secure);
        await storage.saveRepeaterPassword('repeater-abc', 'hunter2');
        await storage.saveRepeaterPassword('repeater-def', 'swordfish');
        await secure.write('unrelated_key', 'untouched');

        await storage.clearAllRepeaterPasswords();

        expect(await storage.getRepeaterPassword('repeater-abc'), isNull);
        expect(await storage.getRepeaterPassword('repeater-def'), isNull);
        expect(await secure.read('unrelated_key'), 'untouched');
      },
    );

    test(
      'getRepeaterPassword migrates a pre-encryption plaintext entry into secure storage',
      () async {
        final prefs = PrefsManager.instance;
        await prefs.setString(
          'repeater_passwords',
          jsonEncode({'repeater-abc': 'hunter2', 'repeater-def': 'swordfish'}),
        );

        final secure = FakeSecureKeyValueStore();
        final storage = StorageService(secureStorage: secure);
        final migrated = await storage.getRepeaterPassword('repeater-abc');

        expect(migrated, 'hunter2');
        expect(await secure.read('repeater_password_repeater-abc'), 'hunter2');
        // Migrating one entry leaves the other legacy entry intact until
        // it's read too, and drops only the migrated key from the blob.
        final remainingLegacy =
            jsonDecode(prefs.getString('repeater_passwords')!)
                as Map<String, dynamic>;
        expect(remainingLegacy, {'repeater-def': 'swordfish'});
      },
    );

    test(
      'saveRepeaterPassword clears any stale legacy plaintext entry for the same key',
      () async {
        final prefs = PrefsManager.instance;
        await prefs.setString(
          'repeater_passwords',
          jsonEncode({'repeater-abc': 'old-plaintext-password'}),
        );

        final storage = StorageService(
          secureStorage: FakeSecureKeyValueStore(),
        );
        await storage.saveRepeaterPassword('repeater-abc', 'new-password');

        final remainingLegacy = prefs.getString('repeater_passwords');
        expect(
          remainingLegacy == null || !remainingLegacy.contains('repeater-abc'),
          isTrue,
        );
        expect(
          await storage.getRepeaterPassword('repeater-abc'),
          'new-password',
        );
      },
    );
  });
}
