import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

class LocalCacheService {
  static const _secureStorage = FlutterSecureStorage();
  static const String _userBoxName = 'user_cache';

  static HiveAesCipher? _cipher;

  static Future<void> init() async {
    await Hive.initFlutter();
    await _initCipher();
  }

  // ==========================================
  // 0. CENTRALIZED ENCRYPTION LOGIC
  // ==========================================

  static Future<void> _initCipher() async {
    if (_cipher != null) return;

    try {
      String? keyString = await _secureStorage.read(key: 'hive_encryption_key');
      if (keyString == null) {
        final newKey = Hive.generateSecureKey();
        keyString = base64UrlEncode(newKey);
        await _secureStorage.write(
            key: 'hive_encryption_key', value: keyString);
      }
      _cipher = HiveAesCipher(base64Url.decode(keyString));
    } catch (e, stack) {
      SecureLogger.logError(
          "Init Cipher", "Failed to initialize Hive cipher", stack);
    }
  }

  static Future<HiveAesCipher> _getCipher() async {
    if (_cipher == null) await _initCipher();
    return _cipher!;
  }

  // ==========================================
  // 1. SECURE USER PROFILE CACHE
  // ==========================================

  static Future<Box> _getSecureUserBox() async {
    final cipher = await _getCipher();
    try {
      if (Hive.isBoxOpen(_userBoxName)) return Hive.box(_userBoxName);
      return await Hive.openBox(_userBoxName, encryptionCipher: cipher);
    } catch (e, stack) {
      SecureLogger.logError(
          "Secure User Box", "Decryption failed. Wiping.", stack);
      await Hive.deleteBoxFromDisk(_userBoxName);
      return await Hive.openBox(_userBoxName, encryptionCipher: cipher);
    }
  }

  static Future<void> saveUserProfile(Map<String, dynamic> data) async {
    try {
      final box = await _getSecureUserBox();
      await box.putAll(data);
    } catch (e, stack) {
      SecureLogger.logError("Save User Profile", e, stack);
    }
  }

  static Future<String?> getCachedUsername() async {
    try {
      final box = await _getSecureUserBox();
      return box.get('username') as String?;
    } catch (e, stack) {
      SecureLogger.logError("Get Cached Username", e, stack);
      return null;
    }
  }

  static Future<void> clearUserCache() async {
    try {
      if (Hive.isBoxOpen(_userBoxName)) {
        await Hive.box(_userBoxName).clear();
      } else {
        await Hive.deleteBoxFromDisk(_userBoxName);
      }
    } catch (e, stack) {
      SecureLogger.logError("Clear User Cache", e, stack);
    }
  }

  // ==========================================
  // 2. DYNAMIC READING HISTORY CACHE (SECURED)
  // ==========================================

  static String get _historyBoxName {
    final user = FirebaseAuth.instance.currentUser;
    return 'reading_history_${user?.uid ?? 'guest'}';
  }

  static Future<Box> getHistoryBox() async {
    final boxName = _historyBoxName;
    final cipher = await _getCipher();

    try {
      if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
      return await Hive.openBox(boxName, encryptionCipher: cipher);
    } catch (e, stack) {
      SecureLogger.logError("History Box", "Decryption failed. Wiping.", stack);
      await Hive.deleteBoxFromDisk(boxName);
      return await Hive.openBox(boxName, encryptionCipher: cipher);
    }
  }

  static Future<void> switchHistoryBox() async {
    await getHistoryBox();
  }

  // ==========================================
  // 3. MANGADEX API CACHE (PLAINTEXT - PERFORMANCE)
  // ==========================================

  static const String _mangaDexBoxName = 'mangadex_cache';

  static Future<Box> _getMangaDexBox() async {
    if (Hive.isBoxOpen(_mangaDexBoxName)) return Hive.box(_mangaDexBoxName);
    return await Hive.openBox(_mangaDexBoxName);
  }

  static Future<dynamic> getMangaDexCache(String key, int durationMs) async {
    try {
      final box = await _getMangaDexBox();
      final timestampKey = '$key-timestamp';

      final cachedData = box.get(key);
      final cachedTimestamp = box.get(timestampKey);

      if (cachedData != null && cachedTimestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - cachedTimestamp < durationMs) {
          return json.decode(cachedData);
        } else {
          await box.delete(key);
          await box.delete(timestampKey);
        }
      }
    } catch (e, stack) {
      SecureLogger.logError("MangaDex Read", e, stack);
    }
    return null;
  }

  static Future<void> saveMangaDexCache(String key, dynamic data) async {
    try {
      final box = await _getMangaDexBox();
      await box.put(key, json.encode(data));
      await box.put('$key-timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e, stack) {
      SecureLogger.logError("MangaDex Write", e, stack);
    }
  }

  static Future<void> cleanMangaDexCache(
      int shortDuration, int longDuration) async {
    try {
      final box = await _getMangaDexBox();
      final keys = box.keys.toList();
      final now = DateTime.now().millisecondsSinceEpoch;

      final keysToDelete = <dynamic>[];

      for (var key in keys) {
        if (key.toString().endsWith('-timestamp')) {
          final timestamp = box.get(key) as int?;
          if (timestamp == null) continue;

          final dataKey = key.toString().replaceAll('-timestamp', '');
          final diff = now - timestamp;
          bool isExpired = false;

          if (dataKey.startsWith('md_pages_')) {
            if (diff > shortDuration) isExpired = true;
          } else {
            if (diff > longDuration) isExpired = true;
          }

          if (isExpired) {
            keysToDelete.add(key);
            keysToDelete.add(dataKey);
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        SecureLogger.info(
            'MangaDex Cleanup: Deleted ${keysToDelete.length ~/ 2} expired entries.');
      }
    } catch (e, stack) {
      SecureLogger.logError("MangaDex Cleanup", e, stack);
    }
  }

  // ==========================================
  // 4. ANILIST API CACHE (PLAINTEXT - PERFORMANCE)
  // ==========================================

  static const String _aniListBoxName = 'manga_cache';

  static Future<Box> _getAniListBox() async {
    if (Hive.isBoxOpen(_aniListBoxName)) return Hive.box(_aniListBoxName);
    return await Hive.openBox(_aniListBoxName);
  }

  static Future<dynamic> getAniListCache(String key, int durationMs) async {
    try {
      final box = await _getAniListBox();
      final timestampKey = '$key-timestamp';

      final cachedData = box.get(key);
      final cachedTimestamp = box.get(timestampKey);

      if (cachedData != null && cachedTimestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - cachedTimestamp < durationMs) {
          return json.decode(cachedData);
        } else {
          await box.deleteAll([key, timestampKey]);
        }
      }
    } catch (e, stack) {
      SecureLogger.logError("AniList Read", e, stack);
    }
    return null;
  }

  static Future<void> saveAniListCache(String key, dynamic data) async {
    try {
      final box = await _getAniListBox();
      await box.put(key, json.encode(data));
      await box.put('$key-timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e, stack) {
      SecureLogger.logError("AniList Write", e, stack);
    }
  }

  static Future<void> cleanAniListCache(int maxDurationMs) async {
    try {
      final box = await _getAniListBox();
      final keys = box.keys.toList();
      final now = DateTime.now().millisecondsSinceEpoch;

      final keysToDelete = <dynamic>[];

      for (var key in keys) {
        if (key.toString().endsWith('-timestamp')) {
          final timestamp = box.get(key) as int?;
          if (timestamp != null && (now - timestamp > maxDurationMs)) {
            keysToDelete.add(key);
            final dataKey = key.toString().replaceAll('-timestamp', '');
            keysToDelete.add(dataKey);
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        SecureLogger.info(
            'AniList Cleanup: Deleted ${keysToDelete.length ~/ 2} expired entries.');
      }
    } catch (e, stack) {
      SecureLogger.logError("AniList Cleanup", e, stack);
    }
  }

  static Future<void> invalidateAniListCaches(List<String> cacheKeys) async {
    try {
      final box = await _getAniListBox();
      final keysToDelete = <dynamic>[];
      for (String key in cacheKeys) {
        keysToDelete.add(key);
        keysToDelete.add('$key-timestamp');
      }
      await box.deleteAll(keysToDelete);
    } catch (e, stack) {
      SecureLogger.logError("AniList Invalidate", e, stack);
    }
  }

  // ==========================================
  // 5. APP SETTINGS CACHE (SECURED)
  // ==========================================

  static const String _settingsBoxName = 'app_settings';

  static Future<Box> _getSettingsBox() async {
    final cipher = await _getCipher();
    try {
      if (Hive.isBoxOpen(_settingsBoxName)) return Hive.box(_settingsBoxName);
      return await Hive.openBox(_settingsBoxName, encryptionCipher: cipher);
    } catch (e, stack) {
      SecureLogger.logError(
          "Settings Box", "Decryption failed. Wiping.", stack);
      await Hive.deleteBoxFromDisk(_settingsBoxName);
      return await Hive.openBox(_settingsBoxName, encryptionCipher: cipher);
    }
  }

  static Future<void> saveAllSettings(Map<String, dynamic> settings) async {
    try {
      final box = await _getSettingsBox();
      await box.putAll(settings);
    } catch (e, stack) {
      SecureLogger.logError("Save Settings", e, stack);
    }
  }

  static Future<void> updateLocalSetting(String key, dynamic value) async {
    try {
      final box = await _getSettingsBox();
      await box.put(key, value);
    } catch (e, stack) {
      SecureLogger.logError("Update Setting", e, stack);
    }
  }

  static Future<dynamic> getSetting(String key, {dynamic defaultValue}) async {
    try {
      final box = await _getSettingsBox();
      return box.get(key, defaultValue: defaultValue);
    } catch (e) {
      return defaultValue;
    }
  }

  static Future<List<String>> getAllowedContentRatings() async {
    final bool isNsfw = await getSetting('nsfw', defaultValue: false);
    if (isNsfw) {
      return ['safe', 'suggestive', 'erotica', 'pornographic'];
    }
    return ['safe', 'suggestive'];
  }

  // ==========================================
  // 6. PHYSICAL IMAGE CACHE (COVERS vs PAGES)
  // ==========================================

  // Change from CacheManager to OtakuImageCacheManager
  static final OtakuImageCacheManager coversCache = OtakuImageCacheManager(
    Config(
      'otaku_covers_cache',
      stalePeriod: const Duration(days: 15),
      maxNrOfCacheObjects: 800,
    ),
  );

  // Change from CacheManager to OtakuImageCacheManager
  static final OtakuImageCacheManager pagesCache = OtakuImageCacheManager(
    Config(
      'otaku_pages_cache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 3000,
    ),
  );

  static Future<void> clearCoverCaches() async {
    try {
      await coversCache.emptyCache();
      SecureLogger.info("Cover caches physically cleared.");
    } catch (e, stack) {
      SecureLogger.logError("Clear Covers", e, stack);
    }
  }

  static Future<void> clearPageCaches() async {
    try {
      await pagesCache.emptyCache();
      SecureLogger.info("Page caches physically cleared.");
    } catch (e, stack) {
      SecureLogger.logError("Clear Pages", e, stack);
    }
  }

  static Future<void> clearAllImageCaches() async {
    try {
      await coversCache.emptyCache();
      await pagesCache.emptyCache();
      SecureLogger.info("Image caches physically cleared.");
    } catch (e, stack) {
      SecureLogger.logError("Clear Images", e, stack);
    }
  }
}

class OtakuImageCacheManager extends CacheManager with ImageCacheManager {
  OtakuImageCacheManager(Config config) : super(config);
}
