import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:otakulink/core/api/anilist_queries.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

// --- MODEL CLASSES ---
class PaginatedResult {
  final List<dynamic> items;
  final bool hasNextPage;
  final int lastPage;
  final int currentPage;

  PaginatedResult({
    required this.items,
    required this.hasNextPage,
    required this.lastPage,
    required this.currentPage,
  });
}

class AniListService {
  static const String _apiUrl = 'https://graphql.anilist.co';
  static const int _cacheDuration = 10800000; // 3 Hours
  static const Duration _timeoutDuration = Duration(seconds: 20);

  static DateTime _nextAllowedRequestTime = DateTime.now();
  static const Duration _minRequestInterval = Duration(milliseconds: 800);

  // --- MAINTENANCE ---
  static Future<void> cleanCache() async {
    await LocalCacheService.cleanAniListCache(_cacheDuration);
  }

  static Future<void> invalidateSpecificCaches(List<String> cacheKeys) async {
    await LocalCacheService.invalidateAniListCaches(cacheKeys);
  }

  // --- INTERNAL HELPER: NETWORK REQUEST ---
  static Future<http.Response> _performRequest({
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    int attempts = 0;
    const int maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;

      final now = DateTime.now();
      DateTime targetExecutionTime = _nextAllowedRequestTime;

      if (now.isAfter(targetExecutionTime)) targetExecutionTime = now;
      _nextAllowedRequestTime = targetExecutionTime.add(_minRequestInterval);

      if (targetExecutionTime.isAfter(now)) {
        await Future.delayed(targetExecutionTime.difference(now));
      }

      try {
        final response = await http
            .post(
              Uri.parse(_apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: json.encode({'query': query, 'variables': variables ?? {}}),
            )
            .timeout(_timeoutDuration);

        if (response.statusCode == 200) return response;

        if (response.statusCode == 429) {
          SecureLogger.info('AniList Rate Limit Hit. Handling backoff...');
          int waitSeconds = 60;

          if (response.headers.containsKey('retry-after')) {
            waitSeconds = int.tryParse(response.headers['retry-after']!) ?? 60;
          } else if (response.headers.containsKey('x-ratelimit-reset')) {
            final resetTimeEpoch =
                int.tryParse(response.headers['x-ratelimit-reset']!);
            if (resetTimeEpoch != null) {
              final resetDate =
                  DateTime.fromMillisecondsSinceEpoch(resetTimeEpoch * 1000);
              final difference = resetDate.difference(DateTime.now()).inSeconds;
              if (difference > 0) waitSeconds = difference;
            }
          }

          _nextAllowedRequestTime =
              DateTime.now().add(Duration(seconds: waitSeconds + 1));
          await Future.delayed(Duration(seconds: waitSeconds + 1));
          continue;
        }

        return response;
      } on TimeoutException catch (_) {
        SecureLogger.info('Request timed out (Attempt $attempts)');
        if (attempts == maxAttempts) rethrow;
      } catch (e, stack) {
        SecureLogger.logError('Network error', e, stack);
        if (attempts == maxAttempts) rethrow;
      }
    }
    throw Exception(
        'Failed to connect to AniList after $maxAttempts attempts.');
  }

  // --- PUBLIC FETCHERS ---

  static Future<List<dynamic>> fetchStandardList({
    required String query,
    required String cacheKey,
    required bool forceRefresh,
    required bool isNsfw, // <-- ADDED: Now requires strict parameter
    Map<String, dynamic>? variables,
  }) async {
    try {
      final Map<String, dynamic> finalVariables =
          variables != null ? Map.from(variables) : {};

      if (!isNsfw) {
        finalVariables['isAdult'] = false;
      }

      final actualCacheKey = isNsfw ? '${cacheKey}_nsfw' : cacheKey;

      if (!forceRefresh) {
        final cachedData = await LocalCacheService.getAniListCache(
            actualCacheKey, _cacheDuration);
        if (cachedData != null) {
          return List<dynamic>.from(cachedData);
        }
      }

      final response =
          await _performRequest(query: query, variables: finalVariables);

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);

        if (body['errors'] != null) {
          throw Exception(
              'AniList GraphQL Error: ${body['errors'][0]['message']}');
        }

        var data = body['data']['Page']['media'];

        final formattedData = (data as List).map((item) {
          return {
            'id': item['id'],
            'title': {
              'english': item['title']['english'],
              'romaji': item['title']['romaji'],
              'display': item['title']['english'] ??
                  item['title']['romaji'] ??
                  'Unknown',
            },
            'coverImage': item['coverImage'],
            'bannerImage': item['bannerImage'],
            'averageScore': item['averageScore'],
            'type': item['type'] ?? 'Manga',
            'status': item['status'] ?? 'Unknown',
            'year': item['startDate']['year']?.toString() ?? '-',
            'genres': item['genres'] ?? [],
            'chapters': item['chapters'],
          };
        }).toList();

        await LocalCacheService.saveAniListCache(actualCacheKey, formattedData);
        return formattedData;
      } else {
        throw Exception('AniList Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      SecureLogger.logError("Fetch Standard List", e, stack);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchRecommendations(
      int sourceId, String? currentTitle) async {
    final cacheKey = 'recs_$sourceId';

    final cachedData =
        await LocalCacheService.getAniListCache(cacheKey, _cacheDuration);
    if (cachedData != null) return cachedData as Map<String, dynamic>;

    try {
      final response = await _performRequest(
          query: AniListQueries.queryRecommendations,
          variables: {'id': sourceId});

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        final media = body['data']['Media'];
        if (media == null) return null;

        String sourceTitle = currentTitle ?? 'Favorites';
        if (sourceTitle == 'Favorites') {
          sourceTitle = media['title']['english'] ?? media['title']['romaji'];
        }

        final rawRecs = media['recommendations']['nodes'] as List;

        final recs = rawRecs
            .where((node) => node['mediaRecommendation'] != null)
            .map((node) {
          final item = node['mediaRecommendation'];
          return {
            'id': item['id'],
            'title': {
              'english': item['title']['english'],
              'romaji': item['title']['romaji'],
              'display': item['title']['english'] ?? item['title']['romaji'],
            },
            'coverImage': {
              'large': item['coverImage']['large'],
              'medium': item['coverImage']['medium'],
              'color': item['coverImage']['color'],
            },
            'averageScore': item['averageScore'],
            'status': item['status'],
            'type': item['type'],
          };
        }).toList();

        if (recs.isEmpty) return null;

        final resultData = {'sourceTitle': sourceTitle, 'data': recs};
        await LocalCacheService.saveAniListCache(cacheKey, resultData);

        return resultData;
      }
    } catch (e, stack) {
      SecureLogger.logError("Fetch Recommendations", e, stack);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getMangaDetails(int id) async {
    final cacheKey = 'manga_details_$id';

    final cachedData =
        await LocalCacheService.getAniListCache(cacheKey, _cacheDuration);
    if (cachedData != null) return cachedData as Map<String, dynamic>;

    try {
      final response = await _performRequest(
        query: AniListQueries.queryMangaDetails,
        variables: {'id': id},
      );

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        if (body['errors'] != null) return null;

        final data = body['data']['Media'];

        String? exactMangaDexId;
        final links = data['externalLinks'] as List? ?? [];

        for (var link in links) {
          if (link['site'] == 'MangaDex') {
            final url = link['url'] as String;
            final parts = url.split('/title/');
            if (parts.length > 1) {
              exactMangaDexId = parts[1].split('/')[0];
            }
            break;
          }
        }

        data['exactMangaDexId'] = exactMangaDexId;
        await LocalCacheService.saveAniListCache(cacheKey, data);

        return data;
      }
    } catch (e, stack) {
      SecureLogger.logError("Get Manga Details", e, stack);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPersonDetails(
      int id, bool isStaff) async {
    final String typeKey = isStaff ? 'staff' : 'char';
    final cacheKey = 'person_${typeKey}_$id';

    final cachedData =
        await LocalCacheService.getAniListCache(cacheKey, _cacheDuration);
    if (cachedData != null) return cachedData as Map<String, dynamic>;

    try {
      final response = await _performRequest(
        query: isStaff
            ? AniListQueries.queryStaffDetails
            : AniListQueries.queryCharacterDetails,
        variables: {'id': id},
      );

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        if (body['errors'] != null) return null;

        final data = body['data'][isStaff ? 'Staff' : 'Character'];
        await LocalCacheService.saveAniListCache(cacheKey, data);

        return data;
      }
    } catch (e, stack) {
      SecureLogger.logError("Get Person Details", e, stack);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getFullPersonList({
    required int mediaId,
    required bool isStaff,
    int page = 1,
  }) async {
    try {
      final response = await _performRequest(
        query: isStaff
            ? AniListQueries.queryAllStaff
            : AniListQueries.queryAllCharacters,
        variables: {'id': mediaId, 'page': page},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final media = body['data']['Media'];
        return media[isStaff ? 'staff' : 'characters'];
      }
    } catch (e, stack) {
      SecureLogger.logError("Get Full Person List", e, stack);
    }
    return null;
  }

  static Future<PaginatedResult?> fetchPaginatedManga({
    required int page,
    required bool isNsfw, // <-- ADDED: Now requires strict parameter
    List<String> sort = const ['TRENDING_DESC'],
    String? status,
    int? minScore,
    String? country,
    int? yearGreater,
  }) async {
    final Map<String, dynamic> variables = {
      'page': page,
      'sort': sort,
    };

    if (status != null) variables['status'] = status;
    if (country != null) variables['country'] = country;
    if (minScore != null) variables['minScore'] = minScore;
    if (yearGreater != null) variables['year'] = yearGreater * 10000;

    if (!isNsfw) {
      variables['isAdult'] = false;
    }

    try {
      final response = await _performRequest(
          query: AniListQueries.queryPaginatedManga, variables: variables);

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);

        if (body['errors'] != null) {
          SecureLogger.info('GraphQL Error: ${body['errors']}');
          return null;
        }

        final pageData = body['data']['Page'];
        final mediaList = pageData['media'] as List;
        final pageInfo = pageData['pageInfo'];

        final formattedItems = mediaList
            .map((item) => {
                  'id': item['id'],
                  'title': {
                    'english': item['title']['english'],
                    'romaji': item['title']['romaji'],
                    'display': item['title']['english'] ??
                        item['title']['romaji'] ??
                        'Unknown',
                  },
                  'coverImage': item['coverImage'],
                  'averageScore': item['averageScore'],
                  'status': item['status'],
                  'year': item['startDate']['year'],
                })
            .toList();

        return PaginatedResult(
          items: formattedItems,
          hasNextPage: pageInfo['hasNextPage'] ?? false,
          lastPage: pageInfo['lastPage'] ?? 1,
          currentPage: pageInfo['currentPage'] ?? page,
        );
      }
    } catch (e, stack) {
      SecureLogger.logError("Fetch Paginated", e, stack);
    }
    return null;
  }

  static Future<PaginatedResult?> fetchPaginatedRecommendations(
      {required int mangaId, required int page}) async {
    try {
      final response = await _performRequest(
        query: AniListQueries.queryPaginatedRecommendations,
        variables: {'id': mangaId, 'page': page},
      );

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        if (body['errors'] != null) return null;

        final recsData = body['data']['Media']['recommendations'];
        final pageInfo = recsData['pageInfo'];
        final nodes = recsData['nodes'] as List;

        final formattedItems = nodes
            .where((node) => node['mediaRecommendation'] != null)
            .map((node) {
          final item = node['mediaRecommendation'];
          return {
            'id': item['id'],
            'title': {
              'english': item['title']['english'],
              'romaji': item['title']['romaji'],
              'display': item['title']['english'] ??
                  item['title']['romaji'] ??
                  'Unknown',
            },
            'coverImage': item['coverImage'],
            'averageScore': item['averageScore'],
            'status': item['status'],
            'year': item['startDate']['year'],
          };
        }).toList();

        return PaginatedResult(
          items: formattedItems,
          hasNextPage: pageInfo['hasNextPage'] ?? false,
          lastPage: pageInfo['lastPage'] ?? 1,
          currentPage: pageInfo['currentPage'] ?? page,
        );
      }
    } catch (e, stack) {
      SecureLogger.logError("Paginated Recs", e, stack);
    }
    return null;
  }

  static Future<Map<String, List<String>>> fetchAvailableFilters() async {
    const cacheKey = 'anilist_filters_list';
    const int filtersCacheDuration = 86400000; // 24 hours

    final cachedData =
        await LocalCacheService.getAniListCache(cacheKey, filtersCacheDuration);
    if (cachedData != null) {
      return {
        'genres': List<String>.from(cachedData['genres']),
        'tags': List<String>.from(cachedData['tags']),
      };
    }

    try {
      final response =
          await _performRequest(query: AniListQueries.getGenresAndTags);

      if (response.statusCode == 200) {
        final body = await Isolate.run(
            () => jsonDecode(response.body) as Map<String, dynamic>);
        final data = body['data'];

        final List<String> genres =
            List<String>.from(data['GenreCollection']).toList();
        final List<dynamic> rawTags = data['MediaTagCollection'];
        final List<String> tags =
            rawTags.map((t) => t['name'].toString()).toList();

        genres.sort();
        tags.sort();

        final result = {'genres': genres, 'tags': tags};
        await LocalCacheService.saveAniListCache(cacheKey, result);

        return result;
      }
    } catch (e, stack) {
      SecureLogger.logError("Fetch Filters", e, stack);
    }

    return {
      'genres': [
        'Action',
        'Adventure',
        'Comedy',
        'Drama',
        'Fantasy',
        'Horror',
        'Romance',
        'Sci-Fi',
        'Slice of Life',
        'Sports'
      ],
      'tags': ['Isekai', 'Revenge', 'Time Travel']
    };
  }
}
