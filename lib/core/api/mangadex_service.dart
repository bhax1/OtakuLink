import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';
  static const Duration _timeout = Duration(seconds: 15);

  static const int _longCacheDuration = 10800000;
  static const int _shortCacheDuration = 1200000;

  static Map<String, String> get _headers => {
        'User-Agent': 'OtakuLink/1.0 (otakulink.dev@gmail.com)',
        'Accept': 'application/json',
      };

  // --- RATE LIMITING ARCHITECTURE ---
  static bool _isRequesting = false;
  static final List<Completer<void>> _requestQueue = [];
  static DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minRequestIntervalMs = 250; // Max 4 requests per second

  static Future<void> _acquireRateLimitLock() async {
    if (_isRequesting) {
      final completer = Completer<void>();
      _requestQueue.add(completer);
      await completer.future;
    }
    _isRequesting = true;

    final now = DateTime.now();
    final timeSinceLastRequest =
        now.difference(_lastRequestTime).inMilliseconds;
    if (timeSinceLastRequest < _minRequestIntervalMs) {
      await Future.delayed(
          Duration(milliseconds: _minRequestIntervalMs - timeSinceLastRequest));
    }
    _lastRequestTime = DateTime.now();
  }

  static void _releaseRateLimitLock() {
    _isRequesting = false;
    if (_requestQueue.isNotEmpty) {
      final next = _requestQueue.removeAt(0);
      next.complete();
    }
  }

  static Future<http.Response> _sendRequest(Uri uri, {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      await _acquireRateLimitLock();
      http.Response response;

      try {
        response = await http.get(uri, headers: _headers).timeout(_timeout);
      } catch (e, stack) {
        _releaseRateLimitLock();
        if (i == retries - 1) {
          SecureLogger.logError(
              "MangaDex Request", "Max retries reached", stack);
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
        continue;
      }

      _releaseRateLimitLock();

      if (response.statusCode == 429) {
        final retryAfterStr = response.headers['retry-after'] ??
            response.headers['x-ratelimit-retry-after'];
        int waitSeconds = 1;

        if (retryAfterStr != null) {
          waitSeconds = int.tryParse(retryAfterStr) ?? 1;
        } else {
          waitSeconds = 2 * (i + 1);
        }

        SecureLogger.info(
            'MD Rate Limit (429) Hit. Waiting $waitSeconds seconds...');
        await Future.delayed(Duration(seconds: waitSeconds));
        continue;
      }

      if (response.statusCode >= 500 && response.statusCode <= 599) {
        if (i == retries - 1) return response;
        SecureLogger.info(
            'MD Server Error (${response.statusCode}). Retrying...');
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
        continue;
      }

      return response;
    }
    throw Exception('Failed to fetch after $retries retries: $uri');
  }

  static int _getGroupPriorityScore(String groupName) {
    final lower = groupName.toLowerCase().trim();
    final premiumGroups = [
      'asura scans',
      'reaper scans',
      'flame scans',
      'leviatan scans',
      'luminous scans',
      'void scans',
      'biamam',
      'galaxy degen scans',
      'mangastream'
    ];
    if (premiumGroups.any((g) => lower.contains(g))) return 3;
    if (lower == 'no group' || lower == 'unknown group' || lower == 'unknown')
      return 1;
    return 2;
  }

  // --- PUBLIC METHODS ---

  static Future<String?> searchMangaId(String title) async {
    final cacheKey = 'md_search_${title.toLowerCase().trim()}';

    final cachedId =
        await LocalCacheService.getMangaDexCache(cacheKey, _longCacheDuration);
    if (cachedId != null) return cachedId as String;

    final contentRatings = await LocalCacheService.getAllowedContentRatings();

    final uri = Uri.parse('$_baseUrl/manga').replace(queryParameters: {
      'title': title,
      'limit': '5',
      'order[relevance]': 'desc',
      'contentRating[]': contentRatings,
    });

    try {
      final response = await _sendRequest(uri);

      if (response.statusCode == 200) {
        final data = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        if (data['data'].isNotEmpty) {
          final id = data['data'][0]['id'];
          await LocalCacheService.saveMangaDexCache(cacheKey, id);
          return id;
        }
      }
    } catch (e, stack) {
      SecureLogger.logError("MD Search", e, stack);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getChapters(
      String mangaDexId) async {
    final String userLang = await LocalCacheService.getSetting(
        'content_language',
        defaultValue: 'en');
    final cacheKey = 'md_chapters_${mangaDexId}_$userLang';

    final cachedList =
        await LocalCacheService.getMangaDexCache(cacheKey, _longCacheDuration);
    if (cachedList != null) {
      return List<Map<String, dynamic>>.from(cachedList);
    }

    List<Map<String, dynamic>> allChapters = [];
    int offset = 0;
    const int limit = 500;
    bool hasMore = true;

    while (hasMore) {
      final uri = Uri.parse('$_baseUrl/manga/$mangaDexId/feed')
          .replace(queryParameters: {
        'translatedLanguage[]': userLang,
        'order[chapter]': 'asc',
        'limit': '$limit',
        'offset': '$offset',
        'includes[]': 'scanlation_group',
      });

      try {
        final response = await _sendRequest(uri);

        if (response.statusCode == 200) {
          final data = await Isolate.run(
              () => jsonDecode(response.body) as Map<String, dynamic>);
          final List rawChapters = data['data'];

          if (rawChapters.isEmpty) {
            hasMore = false;
            break;
          }

          final validChapters = rawChapters.where((ch) {
            final attr = ch['attributes'];
            if (attr['externalUrl'] != null &&
                attr['externalUrl'].toString().isNotEmpty) return false;
            if (attr['pages'] != null && attr['pages'] == 0) return false;
            return true;
          });

          final batch = validChapters.map((ch) {
            final attr = ch['attributes'];
            String groupName = 'Unknown Group';
            final relationships = ch['relationships'] as List? ?? [];
            final group = relationships.firstWhere(
                (r) => r['type'] == 'scanlation_group',
                orElse: () => null);
            if (group != null && group['attributes'] != null) {
              groupName = group['attributes']['name'] ?? 'Unknown';
            }

            return {
              'id': ch['id'],
              'chapter': attr['chapter'] ?? '?',
              'title': attr['title'] ?? '',
              'group': groupName,
            };
          }).toList();

          allChapters.addAll(batch);

          if (rawChapters.length < limit) {
            hasMore = false;
          } else {
            offset += limit;
          }
        } else {
          hasMore = false;
        }
      } catch (e, stack) {
        SecureLogger.logError("MD Chapters Loop", e, stack);
        hasMore = false;
      }
    }

    if (allChapters.isNotEmpty) {
      for (var ch in allChapters) {
        final raw = ch['chapter'];
        ch['chapter'] = (raw != null &&
                raw.toString().trim().isNotEmpty &&
                raw.toString() != 'null')
            ? raw.toString()
            : 'Oneshot';
      }

      allChapters.sort((a, b) {
        double parse(String ch) {
          if (ch == 'Oneshot') return 0.0;
          return double.tryParse(ch) ?? 0.0;
        }

        return parse(a['chapter']).compareTo(parse(b['chapter']));
      });

      final uniqueChaptersMap = <String, Map<String, dynamic>>{};
      for (var ch in allChapters) {
        final chNum = ch['chapter'] as String;
        final currentScore = _getGroupPriorityScore(ch['group'] as String);

        if (!uniqueChaptersMap.containsKey(chNum)) {
          uniqueChaptersMap[chNum] = ch;
        } else {
          final existingGroup = uniqueChaptersMap[chNum]!['group'] as String;
          final existingScore = _getGroupPriorityScore(existingGroup);
          if (currentScore > existingScore) {
            uniqueChaptersMap[chNum] = ch;
          }
        }
      }
      allChapters = uniqueChaptersMap.values.toList();
      await LocalCacheService.saveMangaDexCache(cacheKey, allChapters);
    }

    return allChapters;
  }

  static Future<List<String>> getChapterPages(String chapterId) async {
    final isDataSaver =
        await LocalCacheService.getSetting('data_saver', defaultValue: false);
    final qualityKey = isDataSaver ? 'saver' : 'high';
    final cacheKey = 'md_pages_${chapterId}_$qualityKey';

    final cachedPages =
        await LocalCacheService.getMangaDexCache(cacheKey, _shortCacheDuration);
    if (cachedPages != null) {
      return List<String>.from(cachedPages);
    }

    try {
      final uri = Uri.parse('$_baseUrl/at-home/server/$chapterId');
      final response = await _sendRequest(uri);

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        final baseUrl = body['baseUrl'];
        final hash = body['chapter']['hash'];

        final folderName = isDataSaver ? 'dataSaver' : 'data';
        final urlPath = isDataSaver ? 'data-saver' : 'data';

        final List<dynamic> filenames = body['chapter'][folderName];
        final pages =
            filenames.map((file) => '$baseUrl/$urlPath/$hash/$file').toList();

        await LocalCacheService.saveMangaDexCache(cacheKey, pages);
        return pages;
      }
    } catch (e, stack) {
      SecureLogger.logError("MD Pages Fetch", e, stack);
    }
    return [];
  }

  static Future<void> cleanCache() async {
    await LocalCacheService.cleanMangaDexCache(
        _shortCacheDuration, _longCacheDuration);
  }
}
