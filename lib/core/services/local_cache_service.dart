import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

class LocalCacheService {
  /// Save AniList responses locally with a timestamp marker
  static Future<void> saveAniListCache(String cacheKey, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await prefs.setString(cacheKey, json.encode(cacheData));
  }

  /// Retrieve active AniList JSON caches, discarding them automatically if they exceed maxDuration
  static Future<dynamic> getAniListCache(
    String cacheKey,
    int maxDurationMs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawString = prefs.getString(cacheKey);

    if (rawString != null) {
      try {
        final decoded = json.decode(rawString) as Map<String, dynamic>;
        final int timestamp = decoded['timestamp'] as int;

        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < maxDurationMs) {
          // The cache is still fresh and valid
          return decoded['data'];
        } else {
          // The cache has expired, trash it invisibly so the app falls back to API
          await prefs.remove(cacheKey);
        }
      } catch (e, stack) {
        // Corrupted JSON structure, delete it securely
        SecureLogger.logError("LocalCacheService getAniListCache", e, stack);
        await prefs.remove(cacheKey);
      }
    }
    return null; // Signals the frontend to execute a fresh network GraphQL request
  }

  /// Forces complete destruction of expired memory slots specifically targeting AniList items
  static Future<void> cleanAniListCache(int maxDurationMs) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('anilist_') ||
              k.startsWith('recs_') ||
              k.startsWith('person_') ||
              k.startsWith('manga_details_'),
        )
        .toList();

    for (final key in keys) {
      final rawString = prefs.getString(key);
      if (rawString != null) {
        try {
          final decoded = json.decode(rawString) as Map<String, dynamic>;
          final int timestamp = decoded['timestamp'] as int;
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;

          if (age >= maxDurationMs) {
            await prefs.remove(key);
          }
        } catch (_) {
          await prefs.remove(key);
        }
      }
    }
  }

  /// Save MangaDex data locally
  static Future<void> saveMangaDexCache(String cacheKey, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await prefs.setString(cacheKey, json.encode(cacheData));
  }

  /// Retrieve active MangaDex data
  static Future<dynamic> getMangaDexCache(
    String cacheKey,
    int maxDurationMs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawString = prefs.getString(cacheKey);

    if (rawString != null) {
      try {
        final decoded = json.decode(rawString) as Map<String, dynamic>;
        final int timestamp = decoded['timestamp'] as int;

        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < maxDurationMs) {
          return decoded['data'];
        } else {
          await prefs.remove(cacheKey);
        }
      } catch (e, stack) {
        SecureLogger.logError("LocalCacheService getMangaDexCache", e, stack);
        await prefs.remove(cacheKey);
      }
    }
    return null;
  }

  /// Clean expired MangaDex caches
  static Future<void> cleanMangaDexCache(
    int shortDuration,
    int longDuration,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('md_')).toList();

    for (final key in keys) {
      final rawString = prefs.getString(key);
      if (rawString != null) {
        try {
          final decoded = json.decode(rawString) as Map<String, dynamic>;
          final int timestamp = decoded['timestamp'] as int;
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;

          final duration = key.contains('_pages_')
              ? shortDuration
              : longDuration;
          if (age >= duration) {
            await prefs.remove(key);
          }
        } catch (_) {
          await prefs.remove(key);
        }
      }
    }
  }

  /// Wipe all cached JSON data entirely
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('anilist_') ||
              k.startsWith('recs_') ||
              k.startsWith('person_') ||
              k.startsWith('manga_details_') ||
              k.startsWith('md_'),
        )
        .toList();

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Get a setting value
  static Future<T> getSetting<T>(String key, {required T defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(key);
    if (value == null) return defaultValue;
    return value as T;
  }

  /// Save a setting value
  static Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  /// Get content ratings allowed by user
  static Future<List<String>> getAllowedContentRatings() async {
    final isNsfw = await getSetting('nsfw_enabled', defaultValue: false);
    if (isNsfw) return ['safe', 'suggestive', 'erotica', 'pornographic'];
    return ['safe', 'suggestive'];
  }

  /// Manually wipe exact queries for Pull-To-Refresh sync requests
  static Future<void> invalidateAniListCaches(List<String> cacheKeys) async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in cacheKeys) {
      await prefs.remove(key);
      await prefs.remove('${key}_nsfw');
    }
  }
}
