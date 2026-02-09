import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class NewsArticle {
  final String title;
  final String link;
  final String description;
  final String pubDate;
  final String category; // 'Manga', 'Novel', etc.
  final String? imageUrl;

  NewsArticle({
    required this.title,
    required this.link,
    required this.description,
    required this.pubDate,
    required this.category,
    this.imageUrl,
  });
}

class NewsService {
  // We use the general feed, but we will filter it manually below
  static const String _feedUrl = 'https://www.animenewsnetwork.com/news/rss.xml?ann-edition=w';

  static Future<List<NewsArticle>> fetchNews() async {
    try {
      final response = await http.get(Uri.parse(_feedUrl));
      
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        List<NewsArticle> filteredNews = [];

        for (var node in items) {
          final title = node.findElements('title').single.innerText;
          final description = node.findElements('description').single.innerText;
          final category = node.findElements('category').isNotEmpty 
              ? node.findElements('category').first.innerText 
              : 'News';

          // --- SMART FILTER LOGIC ---
          // 1. Define keywords for content we WANT
          final wants = ['manga', 'novel', 'manhwa', 'webtoon', 'comic', 'print', 'magazine', 'serialization', 'volume', 'author', 'illustrator'];
          // 2. Define keywords for content we HATE (Anime specific)
          final hates = ['anime', 'episode', 'broadcast', 'streaming', 'crunchyroll', 'blu-ray', 'dvd', 'preview', 'cast', 'screening'];

          final textToCheck = '$title $description $category'.toLowerCase();

          // Check: Must contain at least one "Want" AND typically avoid "Hate" (unless it's a big adaptation announcement)
          // For safety, we will just prioritize the positive keywords strongly.
          bool isRelevant = wants.any((word) => textToCheck.contains(word));
          
          // Double check: If it's PURELY anime news (e.g. "Episode 5 Preview"), discard it even if it mentions the manga name.
          if (title.toLowerCase().contains('episode') || title.toLowerCase().contains('broadcast')) {
            isRelevant = false;
          }

          if (isRelevant) {
            // Extract Image
            String? imgUrl;
            final imgRegExp = RegExp(r'<img[^>]+src="([^">]+)"');
            final match = imgRegExp.firstMatch(description);
            if (match != null) {
              imgUrl = match.group(1);
            }

            // Determine display category for the badge
            String displayCat = 'News';
            if (textToCheck.contains('novel')) displayCat = 'NOVEL';
            else if (textToCheck.contains('manhwa') || textToCheck.contains('webtoon')) displayCat = 'WEBTOON';
            else if (textToCheck.contains('manga')) displayCat = 'MANGA';

            filteredNews.add(NewsArticle(
              title: title,
              link: node.findElements('link').single.innerText,
              description: description.replaceAll(RegExp(r'<[^>]*>'), ''), // Clean HTML
              pubDate: node.findElements('pubDate').single.innerText,
              category: displayCat,
              imageUrl: imgUrl,
            ));
          }
        }

        return filteredNews.take(10).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching news: $e");
      return [];
    }
  }
}