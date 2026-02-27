import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

class NewsArticle {
  final String title;
  final String link;
  final String description;
  final String pubDate;
  final String category;
  final String? imageUrl;

  NewsArticle({
    required this.title,
    required this.link,
    required this.description,
    required this.pubDate,
    required this.category,
    this.imageUrl,
  });

  // Added serialization for Hive Cache compatibility
  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'description': description,
        'pubDate': pubDate,
        'category': category,
        'imageUrl': imageUrl,
      };

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        title: json['title'],
        link: json['link'],
        description: json['description'],
        pubDate: json['pubDate'],
        category: json['category'],
        imageUrl: json['imageUrl'],
      );
}

class NewsService {
  static const String _feedUrl =
      'https://www.animenewsnetwork.com/news/rss.xml?ann-edition=w';
  static const Duration _timeout = Duration(seconds: 10);
  static const String _cacheKey = 'ann_news_feed';
  static const int _cacheDurationMs = 10800000; // 3 Hours

  static Future<List<NewsArticle>> fetchNews(
      {bool forceRefresh = false}) async {
    // 1. Check Local Encrypted Cache First
    if (!forceRefresh) {
      final cachedData =
          await LocalCacheService.getAniListCache(_cacheKey, _cacheDurationMs);
      if (cachedData != null) {
        try {
          final List<dynamic> decoded =
              cachedData is String ? json.decode(cachedData) : cachedData;
          return decoded
              .map((item) =>
                  NewsArticle.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        } catch (e, stack) {
          SecureLogger.logError("News Cache Decode", e, stack);
        }
      }
    }

    // 2. Fetch from Network
    try {
      final response = await http.get(Uri.parse(_feedUrl)).timeout(_timeout);

      if (response.statusCode == 200) {
        // SAFETY CHECK: Prevent XML Bomb / DoS
        if (response.bodyBytes.length > 5 * 1024 * 1024) {
          SecureLogger.logError("XML Security",
              "Feed exceeds 5MB limit, aborting to prevent memory exhaustion.");
          return [];
        }

        // 3. OFFLOAD HEAVY PARSING TO BACKGROUND ISOLATE
        final List<NewsArticle> parsedNews =
            await Isolate.run(() => _parseXmlPayload(response.body));

        // 4. Save to Cache
        if (parsedNews.isNotEmpty) {
          final cachePayload =
              parsedNews.map((article) => article.toJson()).toList();
          await LocalCacheService.saveAniListCache(_cacheKey, cachePayload);
        }

        return parsedNews;
      }
    } catch (e, stack) {
      SecureLogger.logError("Fetch News Error", e, stack);
    }

    return [];
  }

  // --- ISOLATE WORKER FUNCTION ---
  // This runs on a separate CPU thread, protecting the UI from jank.
  static List<NewsArticle> _parseXmlPayload(String xmlBody) {
    final unescape = HtmlUnescape();
    final document = XmlDocument.parse(xmlBody);
    final items = document.findAllElements('item');
    List<NewsArticle> filteredNews = [];

    for (var node in items) {
      final titleEl = node.findElements('title');
      final descEl = node.findElements('description');
      final linkEl = node.findElements('link');
      final dateEl = node.findElements('pubDate');

      if (titleEl.isEmpty || descEl.isEmpty) continue;

      final rawTitle = titleEl.first.innerText;
      final title = unescape.convert(rawTitle);
      final rawDesc = descEl.first.innerText;

      final categoryNode = node.findElements('category');
      final categoryText =
          categoryNode.isNotEmpty ? categoryNode.first.innerText : 'News';

      final textToCheck = '$title $rawDesc $categoryText'.toLowerCase();

      final wants = [
        'manga',
        'novel',
        'manhwa',
        'webtoon',
        'comic',
        'print',
        'magazine',
        'serialization',
        'volume',
        'author',
        'illustrator'
      ];

      if (title.toLowerCase().contains('episode') ||
          title.toLowerCase().contains('broadcast') ||
          title.toLowerCase().contains('streaming') ||
          title.toLowerCase().contains('english dub')) {
        continue;
      }

      bool isRelevant = wants.any((word) => textToCheck.contains(word));

      if (isRelevant) {
        String? imgUrl;
        final imgRegExp = RegExp(r'<img[^>]+src="([^">]+)"');
        final match = imgRegExp.firstMatch(rawDesc);

        if (match != null) {
          String rawUrl = match.group(1)!;
          if (rawUrl.startsWith('//')) {
            imgUrl = 'https:$rawUrl';
          } else if (rawUrl.startsWith('/')) {
            imgUrl = 'https://www.animenewsnetwork.com$rawUrl';
          } else {
            imgUrl = rawUrl;
          }
        }

        String displayCat = 'News';
        if (textToCheck.contains('novel'))
          displayCat = 'NOVEL';
        else if (textToCheck.contains('manhwa') ||
            textToCheck.contains('webtoon'))
          displayCat = 'WEBTOON';
        else if (textToCheck.contains('manga')) displayCat = 'MANGA';

        final cleanDesc =
            unescape.convert(rawDesc.replaceAll(RegExp(r'<[^>]*>'), '').trim());

        filteredNews.add(NewsArticle(
          title: title,
          link: linkEl.isNotEmpty ? linkEl.first.innerText : '',
          description: cleanDesc,
          pubDate: dateEl.isNotEmpty ? dateEl.first.innerText : '',
          category: displayCat,
          imageUrl: imgUrl,
        ));
      }
    }
    return filteredNews.take(15).toList();
  }
}
