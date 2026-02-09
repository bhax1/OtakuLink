import 'dart:convert';
import 'package:http/http.dart' as http;

class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';

  // CRITICAL: Identifies your app to avoid blocking
  static Map<String, String> get _headers => {
    'User-Agent': 'OtakuLink/1.0 (bobandre04@gmail.com)', 
    'Accept': 'application/json',
  };

  /// 1. Search for the MangaDex ID using the English or Romaji title
  static Future<String?> searchMangaId(String title) async {
    final uri = Uri.parse('$_baseUrl/manga').replace(queryParameters: {
      'title': title,
      'limit': '5',
      'order[relevance]': 'desc',
      'contentRating[]': ['safe', 'suggestive', 'erotica'],
    });

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'].isNotEmpty) return data['data'][0]['id'];
      }
    } catch (e) {
      print('MD Search Error: $e');
    }
    return null;
  }

  /// 2. Get the list of English chapters + Scanlation Group info
  static Future<List<Map<String, dynamic>>> getChapters(String mangaDexId) async {
    final uri = Uri.parse('$_baseUrl/manga/$mangaDexId/feed').replace(queryParameters: {
      'translatedLanguage[]': 'en',
      'order[chapter]': 'asc',
      'limit': '500',
      'includes[]': 'scanlation_group', // Fetch group info for credit
    });

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List rawChapters = data['data'];

        return rawChapters.map((ch) {
          final attr = ch['attributes'];
          
          // Logic to find Group Name
          String groupName = 'Unknown Group';
          final relationships = ch['relationships'] as List;
          final group = relationships.firstWhere(
            (r) => r['type'] == 'scanlation_group', 
            orElse: () => null
          );
          if (group != null && group['attributes'] != null) {
             groupName = group['attributes']['name'];
          }

          return {
            'id': ch['id'],
            'chapter': attr['chapter'] ?? '?',
            'title': attr['title'] ?? '',
            'group': groupName,
          };
        }).toList();
      }
    } catch (e) {
      print('Chapter Fetch Error: $e');
    }
    return [];
  }

  /// 3. Get pages using Data Saver (Bandwidth Friendly)
  static Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/at-home/server/$chapterId'),
        headers: _headers
      );
      
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final baseUrl = body['baseUrl'];
        final hash = body['chapter']['hash'];
        
        // Use 'dataSaver' for compressed images (Required for mobile apps)
        final List<dynamic> filenames = body['chapter']['dataSaver']; 

        return filenames.map((file) => 
          '$baseUrl/data-saver/$hash/$file'
        ).toList();
      }
    } catch (e) {
      print('Page Fetch Error: $e');
    }
    return [];
  }
}