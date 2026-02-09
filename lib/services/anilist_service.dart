import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

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
  
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 800);

  // --- QUERIES ---
  static const String queryTrendingCarousel = '''
    query {
      Page(page: 1, perPage: 10) {
        media(sort: TRENDING_DESC, type: MANGA, isAdult: false) {
          id
          title { romaji english }
          coverImage { extraLarge large medium color }
          bannerImage
          averageScore
          status
          type
          startDate { year }
          description
          genres
        }
      }
    }
  ''';

  static const String queryNewReleases = '''
    query (\$year: FuzzyDateInt) {
      Page(page: 1, perPage: 15) {
        media(sort: POPULARITY_DESC, type: MANGA, status: RELEASING, startDate_greater: \$year, isAdult: false) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryTrendingList = '''
    query {
      Page(page: 2, perPage: 15) { 
        media(sort: TRENDING_DESC, type: MANGA, isAdult: false) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryHallOfFame = '''
    query {
      Page(page: 1, perPage: 15) {
        media(sort: SCORE_DESC, type: MANGA, averageScore_greater: 88, isAdult: false) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryFanFavorites = '''
    query {
      Page(page: 1, perPage: 15) {
        media(sort: FAVOURITES_DESC, type: MANGA, isAdult: false) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryManhwa = '''
    query {
      Page(page: 1, perPage: 15) {
        media(sort: TRENDING_DESC, type: MANGA, countryOfOrigin: "KR", isAdult: false) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryRecommendations = '''
    query (\$id: Int) {
      Media(id: \$id, type: MANGA) {
        title { romaji english }
        recommendations(perPage: 10, sort: RATING_DESC) {
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { large medium color }
              averageScore
              status
              type
              startDate { year }
            }
          }
        }
      }
    }
  ''';

  static const String queryMangaDetails = '''
    query (\$id: Int) {
      Media (id: \$id, type: MANGA) {
        id
        title { romaji english native }
        coverImage { extraLarge large medium color }
        bannerImage
        description
        status
        genres
        averageScore
        chapters
        volumes             # <--- ADDED: Useful info
        countryOfOrigin     # <--- ADDED: Replaces 'Format'
        startDate { year month day }
        characters (sort: ROLE, perPage: 10) {
          edges { 
            role 
            node { 
              id
              name { full } 
              image { large medium } 
            } 
          }
        }
        staff (sort: RELEVANCE, perPage: 5) {
          edges { 
            role 
            node { 
              id
              name { full } 
              image { large medium } 
            } 
          }
        }
        recommendations (sort: RATING_DESC, perPage: 10) {
          nodes { 
            mediaRecommendation { 
              id 
              title { romaji english } 
              coverImage { large medium color } 
            } 
          }
        }
      }
    }
  ''';

  static const String queryStaffDetails = '''
    query (\$id: Int) {
      Staff(id: \$id) {
        name { full native }
        image { large medium }
        description
        primaryOccupations
        homeTown
        yearsActive
      }
    }
  ''';

  static const String queryCharacterDetails = '''
    query (\$id: Int) {
      Character(id: \$id) {
        name { full native }
        image { large medium }
        description
        gender
        age
        bloodType
      }
    }
  ''';

  static const String queryAllCharacters = '''
    query (\$id: Int, \$page: Int) {
      Media(id: \$id, type: MANGA) {
        characters(page: \$page, perPage: 25, sort: ROLE) {
          pageInfo { hasNextPage currentPage }
          edges {
            role
            node { id name { full } image { large } }
          }
        }
      }
    }
  ''';

  static const String queryAllStaff = '''
    query (\$id: Int, \$page: Int) {
      Media(id: \$id, type: MANGA) {
        staff(page: \$page, perPage: 25, sort: RELEVANCE) {
          pageInfo { hasNextPage currentPage }
          edges {
            role
            node { id name { full } image { large } }
          }
        }
      }
    }
  ''';

  static Future<Map<String, dynamic>?> getFullPersonList({
    required int mediaId,
    required bool isStaff,
    int page = 1,
  }) async {
    try {
      final response = await _performRequest(
        query: isStaff ? queryAllStaff : queryAllCharacters,
        variables: {'id': mediaId, 'page': page},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final media = body['data']['Media'];
        return media[isStaff ? 'staff' : 'characters'];
      }
    } catch (e) {
      print('Error fetching full list: $e');
    }
    return null;
  }

  // --- INTERNAL HELPER: RATE LIMIT HANDLER ---
  static Future<http.Response> _performRequest({
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    int attempts = 0;
    const int maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;
      final now = DateTime.now();
      if (_lastRequestTime != null) {
        final difference = now.difference(_lastRequestTime!);
        if (difference < _minRequestInterval) {
          await Future.delayed(_minRequestInterval - difference);
        }
      }
      _lastRequestTime = DateTime.now();

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({'query': query, 'variables': variables ?? {}}),
      );

      if (response.statusCode == 200) return response;

      if (response.statusCode == 429) {
        print('AniList Rate Limit Hit. Handling backoff...');
        int waitSeconds = 60;
        if (response.headers.containsKey('retry-after')) {
          waitSeconds = int.tryParse(response.headers['retry-after']!) ?? 60;
        } else if (response.headers.containsKey('x-ratelimit-reset')) {
          final resetTimeEpoch = int.tryParse(response.headers['x-ratelimit-reset']!);
          if (resetTimeEpoch != null) {
            final resetDate = DateTime.fromMillisecondsSinceEpoch(resetTimeEpoch * 1000);
            final difference = resetDate.difference(DateTime.now()).inSeconds;
            if (difference > 0) waitSeconds = difference;
          }
        }
        await Future.delayed(Duration(seconds: waitSeconds + 1));
        continue;
      }
      return response;
    }
    throw Exception('Failed to connect to AniList after $maxAttempts attempts.');
  }

  // --- PUBLIC FETCHERS ---
  static Future<List<dynamic>> fetchStandardList({
    required String query,
    required String cacheKey,
    required bool forceRefresh,
    Map<String, dynamic>? variables,
  }) async {
    var box = await Hive.openBox('mangaCache');
    final timestampKey = '$cacheKey-timestamp';

    if (!forceRefresh) {
      final cachedData = box.get(cacheKey);
      final cachedTimestamp = box.get(timestampKey);
      if (cachedData != null && cachedTimestamp != null) {
        if (DateTime.now().millisecondsSinceEpoch - cachedTimestamp < _cacheDuration) {
          return List<dynamic>.from(json.decode(cachedData));
        }
      }
    }

    final response = await _performRequest(query: query, variables: variables);

    if (response.statusCode == 200) {
      var body = json.decode(response.body);
      if (body['errors'] != null) {
          throw Exception('AniList GraphQL Error: ${body['errors'][0]['message']}');
      }

      var data = body['data']['Page']['media'];

      final formattedData = (data as List).map((item) {
        return {
          'id': item['id'],
          'title': {
            'english': item['title']['english'],
            'romaji': item['title']['romaji'],
            'display': item['title']['english'] ?? item['title']['romaji'] ?? 'Unknown',
          },
          'coverImage': {
            'extraLarge': item['coverImage']['extraLarge'],
            'large': item['coverImage']['large'],
            'medium': item['coverImage']['medium'],
            'color': item['coverImage']['color'],
          },
          'bannerImage': item['bannerImage'],
          'averageScore': item['averageScore'],
          'type': item['type'] ?? 'Manga',
          'status': item['status'] ?? 'Unknown',
          'year': item['startDate']['year']?.toString() ?? '-',
          'genres': item['genres'] ?? [],
        };
      }).toList();

      box.put(cacheKey, json.encode(formattedData));
      box.put(timestampKey, DateTime.now().millisecondsSinceEpoch);
      return formattedData;
    } else {
      throw Exception('AniList Error: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<Map<String, dynamic>?> fetchRecommendations(int sourceId, String? currentTitle) async {
    try {
      final response = await _performRequest(
        query: queryRecommendations, 
        variables: {'id': sourceId}
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
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

        return {
          'sourceTitle': sourceTitle,
          'data': recs
        };
      }
    } catch (e) {
      print("Error fetching recommendations: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getMangaDetails(int id) async {
    var box = await Hive.openBox('mangaCache');
    final cacheKey = 'manga_details_$id';
    final timestampKey = '$cacheKey-timestamp';

    // 1. Check Cache
    final cachedData = box.get(cacheKey);
    final cachedTimestamp = box.get(timestampKey);
    if (cachedData != null && cachedTimestamp != null) {
      // 3 Hour validity
      if (DateTime.now().millisecondsSinceEpoch - cachedTimestamp < _cacheDuration) {
        return json.decode(cachedData) as Map<String, dynamic>;
      }
    }

    // 2. Fetch Network
    try {
      final response = await _performRequest(
        query: queryMangaDetails,
        variables: {'id': id},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['errors'] != null) {
          print('GraphQL Errors: ${body['errors']}');
          return null;
        }
        
        final data = body['data']['Media'];
        
        // 3. Save Cache (Raw Map)
        box.put(cacheKey, json.encode(data));
        box.put(timestampKey, DateTime.now().millisecondsSinceEpoch);
        
        return data;
      }
    } catch (e) {
      print('API Error fetching details: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPersonDetails(int id, bool isStaff) async {
    var box = await Hive.openBox('mangaCache');
    final String typeKey = isStaff ? 'staff' : 'char';
    final cacheKey = 'person_${typeKey}_$id';
    final timestampKey = '$cacheKey-timestamp';

    // 1. Check Cache
    final cachedData = box.get(cacheKey);
    final cachedTimestamp = box.get(timestampKey);
    if (cachedData != null && cachedTimestamp != null) {
      if (DateTime.now().millisecondsSinceEpoch - cachedTimestamp < _cacheDuration) {
        return json.decode(cachedData) as Map<String, dynamic>;
      }
    }

    // 2. Fetch Network
    try {
      final response = await _performRequest(
        query: isStaff ? queryStaffDetails : queryCharacterDetails,
        variables: {'id': id},
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['errors'] != null) {
          print('GraphQL Errors: ${body['errors']}');
          return null;
        }
        
        final data = body['data'][isStaff ? 'Staff' : 'Character'];

        // 3. Save Cache
        box.put(cacheKey, json.encode(data));
        box.put(timestampKey, DateTime.now().millisecondsSinceEpoch);

        return data;
      }
    } catch (e) {
      print('API Exception fetching person: $e');
    }
    return null;
  }

  static Future<PaginatedResult?> fetchPaginatedManga({
    required int page,
    List<String> sort = const ['TRENDING_DESC'],
    String? status,
    int? minScore,
    String? country,
    int? yearGreater,
  }) async {
    
    // 1. dynamic variable construction
    final Map<String, dynamic> variables = {'page': page};
    
    // 2. Build the query string dynamically to avoid complex null handling in GraphQL
    String args = 'sort: $sort, type: MANGA, isAdult: false';
    
    if (status != null) args += ', status: $status';
    if (minScore != null) args += ', averageScore_greater: $minScore';
    if (country != null) args += ', countryOfOrigin: "$country"';
    if (yearGreater != null) {
        variables['year'] = yearGreater;
        args += ', startDate_greater: \$year';
    }

    final String query = '''
      query (\$page: Int${yearGreater != null ? ', \$year: FuzzyDateInt' : ''}) {
        Page(page: \$page, perPage: 20) {
          pageInfo { currentPage lastPage hasNextPage }
          media($args) {
            id
            title { romaji english }
            coverImage { extraLarge large medium color }
            averageScore
            status
            type
            startDate { year }
          }
        }
      }
    ''';

    try {
      final response = await _performRequest(query: query, variables: variables);
      
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final pageData = body['data']['Page'];
        final mediaList = pageData['media'] as List;
        final pageInfo = pageData['pageInfo'];

        final formattedItems = mediaList.map((item) => {
           'id': item['id'],
           'title': {
             'english': item['title']['english'],
             'romaji': item['title']['romaji'],
             'display': item['title']['english'] ?? item['title']['romaji'] ?? 'Unknown',
           },
           'coverImage': item['coverImage'],
           'averageScore': item['averageScore'],
           'status': item['status'],
           'year': item['startDate']['year'],
        }).toList();

        return PaginatedResult(
          items: formattedItems,
          hasNextPage: pageInfo['hasNextPage'] ?? false,
          lastPage: pageInfo['lastPage'] ?? 1,
          currentPage: pageInfo['currentPage'] ?? page,
        );
      }
    } catch (e) {
      debugPrint("Paginated fetch error: $e");
    }
    return null;
  }
}