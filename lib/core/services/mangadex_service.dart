import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:otakulink/core/services/local_cache_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/core/constants/app_constants.dart';

class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';
  static const Duration _timeout = Duration(seconds: 15);

  static const int _longCacheDuration = 10800000;
  static const int _shortCacheDuration = 1200000;

  static Map<String, String> get _headers => {
    'User-Agent':
        'OtakuLink/${AppConstants.version} (${AppConstants.contactEmail})',
    'Accept': 'application/json',
  };

  // --- RATE LIMITING ARCHITECTURE ---
  static bool _isRequesting = false;
  static final List<Completer<void>> _requestQueue = [];
  static DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minRequestIntervalMs = 250;

  static Future<void> _acquireRateLimitLock() async {
    if (_isRequesting) {
      final completer = Completer<void>();
      _requestQueue.add(completer);
      await completer.future;
    }
    _isRequesting = true;

    final now = DateTime.now();
    final timeSinceLastRequest = now
        .difference(_lastRequestTime)
        .inMilliseconds;
    if (timeSinceLastRequest < _minRequestIntervalMs) {
      await Future.delayed(
        Duration(milliseconds: _minRequestIntervalMs - timeSinceLastRequest),
      );
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
            "MangaDex Request",
            "Max retries reached",
            stack,
          );
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
        continue;
      }

      _releaseRateLimitLock();

      if (response.statusCode == 429) {
        final retryAfterStr =
            response.headers['retry-after'] ??
            response.headers['x-ratelimit-retry-after'];
        int waitSeconds = 1;

        if (retryAfterStr != null) {
          waitSeconds = int.tryParse(retryAfterStr) ?? 1;
        } else {
          waitSeconds = 2 * (i + 1);
        }

        SecureLogger.info(
          'MD Rate Limit (429) Hit. Waiting $waitSeconds seconds...',
        );
        await Future.delayed(Duration(seconds: waitSeconds));
        continue;
      }

      if (response.statusCode >= 500 && response.statusCode <= 599) {
        if (i == retries - 1) return response;
        SecureLogger.info(
          'MD Server Error (${response.statusCode}). Retrying...',
        );
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
      'mangastream',
    ];
    if (premiumGroups.any((g) => lower.contains(g))) return 3;
    if (lower == 'no group' || lower == 'unknown group' || lower == 'unknown') {
      return 1;
    }
    return 2;
  }

  static String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        // Replace special punctuation with spaces to allow loose matching
        .replaceAll(RegExp(r'[:\-\.\!\?\( \)]'), ' ')
        // Remove multiple spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // --- PUBLIC METHODS ---

  static Future<String?> searchMangaId(String title) async {
    final normalized = _normalizeTitle(title);
    if (normalized.isEmpty) return null;
    
    final cacheKey = 'md_search_${normalized.replaceAll(' ', '_')}';

    final cachedId = await LocalCacheService.getMangaDexCache(
      cacheKey,
      _longCacheDuration,
    );
    if (cachedId != null) return cachedId as String;

    final contentRatings = await LocalCacheService.getAllowedContentRatings();

    final uri = Uri.parse('$_baseUrl/manga').replace(
      queryParameters: {
        'title': title,
        'limit': '5',
        'order[relevance]': 'desc',
        'contentRating[]': contentRatings,
      },
    );

    try {
      final response = await _sendRequest(uri);

      if (response.statusCode == 200) {
        final data = await Isolate.run(
          () => jsonDecode(response.body) as Map<String, dynamic>,
        );

        final dataList = data['data'] as List?;
        if (dataList != null && dataList.isNotEmpty) {
          final bestMatch = dataList[0] as Map<String, dynamic>;
          final id = bestMatch['id'] as String;
          final attributes = bestMatch['attributes'] as Map<String, dynamic>?;
          final titleMap = attributes?['title'] as Map<String, dynamic>?;

          final foundTitle =
              titleMap?['en'] ??
              (titleMap != null && titleMap.values.isNotEmpty
                  ? titleMap.values.first
                  : 'Unknown');

          SecureLogger.info(
            "MangaDexService: Search for '$title' found: '$foundTitle' (ID: $id)",
          );
          await LocalCacheService.saveMangaDexCache(cacheKey, id);
          return id;
        } else {
          SecureLogger.info(
            "MangaDexService: Search for '$title' returned NO results.",
          );
        }
      }
    } catch (e, stack) {
      SecureLogger.logError("MD Search", e, stack);
    }
    return null;
  }

  static Future<String?> searchMangaIdWithFallbacks(List<String> titles) async {
    // 1. Try exact searches for each title
    for (final title in titles) {
      if (title.trim().isEmpty || title.toLowerCase() == 'unknown') continue;
      
      // Try with original title
      final id = await searchMangaId(title);
      if (id != null) return id;

      // Try with normalized title if different
      final normalized = _normalizeTitle(title);
      if (normalized != title.toLowerCase().trim() && normalized.isNotEmpty) {
        final normId = await searchMangaId(normalized);
        if (normId != null) return normId;
      }
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getChapters(
    String mangaDexId,
  ) async {
    final dynamic userLang = await LocalCacheService.getSetting(
      'content_language',
      defaultValue: 'en',
    );
    final cacheKey = 'md_chapters_${mangaDexId}_$userLang';

    final cachedList = await LocalCacheService.getMangaDexCache(
      cacheKey,
      _longCacheDuration,
    );
    if (cachedList != null) {
      SecureLogger.info(
        "MangaDexService: Returning cached chapters for $mangaDexId",
      );
      return List<Map<String, dynamic>>.from(cachedList);
    }

    SecureLogger.info(
      "MangaDexService: getChapters for $mangaDexId with userLang: $userLang",
    );

    List<Map<String, dynamic>> allChapters = [];
    int offset = 0;
    const int limit = 500;
    bool hasMore = true;

    while (hasMore) {
      final Map<String, dynamic> queryParams = {
        'order[chapter]': 'asc',
        'limit': '$limit',
        'offset': '$offset',
        'includes[]': 'scanlation_group',
      };

      if (userLang is Iterable) {
        queryParams['translatedLanguage[]'] = userLang.toList();
      } else if (userLang != null && userLang.toString().isNotEmpty) {
        queryParams['translatedLanguage[]'] = userLang.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/manga/$mangaDexId/feed',
      ).replace(queryParameters: queryParams);
      SecureLogger.info("MangaDexService: Calling API: $uri");

      try {
        final response = await _sendRequest(uri);
        SecureLogger.info(
          "MangaDexService: Response Status: ${response.statusCode}",
        );

        if (response.statusCode == 200) {
          final data = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>,
          );

          final rawChaptersList = data['data'] as List?;
          if (rawChaptersList == null || rawChaptersList.isEmpty) {
            hasMore = false;
            break;
          }

          SecureLogger.info(
            "MangaDexService: Received ${rawChaptersList.length} raw chapters.",
          );

          // Cast to statically typed maps
          final rawChapters = rawChaptersList.cast<Map<String, dynamic>>();

          final validChapters = rawChapters.where((ch) {
            final attr = ch['attributes'] as Map<String, dynamic>?;
            if (attr == null) return false;

            if (attr['externalUrl'] != null &&
                attr['externalUrl'].toString().isNotEmpty) {
              return false;
            }
            if (attr['pages'] != null && attr['pages'] == 0) return false;
            return true;
          });

          final batch = validChapters.map((ch) {
            final attr = ch['attributes'] as Map<String, dynamic>;
            String groupName = 'Unknown Group';

            final relationships =
                (ch['relationships'] as List?)?.cast<Map<String, dynamic>>() ??
                [];
            final group = relationships
                .where((r) => r['type'] == 'scanlation_group')
                .firstOrNull;

            if (group != null && group['attributes'] != null) {
              final groupAttr = group['attributes'] as Map<String, dynamic>;
              groupName = groupAttr['name']?.toString() ?? 'Unknown';
            }

            return {
              'id': ch['id'],
              'chapter': attr['chapter'] ?? '?',
              'title': attr['title'] ?? '',
              'group': groupName,
            };
          }).toList();

          allChapters.addAll(batch);

          if (rawChaptersList.length < limit) {
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
      allChapters = await Isolate.run(() {
        for (var ch in allChapters) {
          final raw = ch['chapter'];
          ch['chapter'] =
              (raw != null &&
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
        return uniqueChaptersMap.values.toList();
      });

      SecureLogger.info(
        "MangaDexService: Returning ${allChapters.length} unique chapters.",
      );
      await LocalCacheService.saveMangaDexCache(cacheKey, allChapters);
    } else {
      SecureLogger.info("MangaDexService: No chapters found for $mangaDexId");
    }

    return allChapters;
  }

  static Future<Map<String, dynamic>?> getLatestChapter(
    String mangaDexId,
  ) async {
    final dynamic userLang = await LocalCacheService.getSetting(
      'content_language',
      defaultValue: 'en',
    );

    final Map<String, dynamic> queryParams = {
      'order[createdAt]': 'desc',
      'limit': '1',
    };

    if (userLang is Iterable) {
      queryParams['translatedLanguage[]'] = userLang.toList();
    } else if (userLang != null && userLang.toString().isNotEmpty) {
      queryParams['translatedLanguage[]'] = userLang.toString();
    }

    final uri = Uri.parse(
      '$_baseUrl/manga/$mangaDexId/feed',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _sendRequest(uri);
      if (response.statusCode == 200) {
        final data = await Isolate.run(
          () => jsonDecode(response.body) as Map<String, dynamic>,
        );
        final rawChaptersList = data['data'] as List?;
        if (rawChaptersList != null && rawChaptersList.isNotEmpty) {
          final ch = rawChaptersList[0] as Map<String, dynamic>;
          final attr = ch['attributes'] as Map<String, dynamic>;
          return {
            'id': ch['id'],
            'chapter': attr['chapter']?.toString() ?? '?',
            'title': attr['title']?.toString() ?? '',
          };
        }
      }
    } catch (e, stack) {
      SecureLogger.logError("MD Latest Chapter", e, stack);
    }
    return null;
  }

  static Future<List<String>> getChapterPages(String chapterId) async {
    final isDataSaver = await LocalCacheService.getSetting(
      'data_saver',
      defaultValue: false,
    );
    final qualityKey = isDataSaver ? 'saver' : 'high';
    final cacheKey = 'md_pages_${chapterId}_$qualityKey';

    final cachedPages = await LocalCacheService.getMangaDexCache(
      cacheKey,
      _shortCacheDuration,
    );
    if (cachedPages != null) {
      return List<String>.from(cachedPages);
    }

    try {
      final uri = Uri.parse('$_baseUrl/at-home/server/$chapterId');
      final response = await _sendRequest(uri);

      if (response.statusCode == 200) {
        final body = await Isolate.run(
          () => jsonDecode(response.body) as Map<String, dynamic>,
        );
        final baseUrl = body['baseUrl'];
        final chapterData = body['chapter'] as Map<String, dynamic>?;

        if (chapterData == null) return [];

        final hash = chapterData['hash'];
        final folderName = isDataSaver ? 'dataSaver' : 'data';
        final urlPath = isDataSaver ? 'data-saver' : 'data';

        final List<dynamic>? filenames = chapterData[folderName];
        if (filenames == null) return [];

        final pages = filenames
            .map((file) => '$baseUrl/$urlPath/$hash/$file')
            .toList();

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
      _shortCacheDuration,
      _longCacheDuration,
    );
  }
}
