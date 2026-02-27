import 'package:flutter/material.dart';
import 'package:otakulink/core/api/news_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsRail extends StatelessWidget {
  const NewsRail({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Color _getBadgeColor(String category) {
    switch (category) {
      case 'NOVEL': return Colors.purple;
      case 'WEBTOON': return Colors.green;
      case 'MANGA': return Colors.redAccent;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: const [
              Icon(Icons.newspaper, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                "Reading News",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: FutureBuilder<List<NewsArticle>>(
            future: NewsService.fetchNews(),
            builder: (context, snapshot) {
              // CHANGED: Use Skeleton Row here
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const NewsSkeletonRow();
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No manga news right now.", style: TextStyle(color: Colors.grey)));
              }

              final news = snapshot.data!;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: news.length,
                itemBuilder: (context, index) {
                  final article = news[index];
                  final badgeColor = _getBadgeColor(article.category);

                  return GestureDetector(
                    onTap: () => _launchUrl(article.link),
                    child: Container(
                      width: 280,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                article.category, 
                                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                article.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.3),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              article.pubDate.length > 16 ? article.pubDate.substring(0, 16) : article.pubDate,
                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class NewsSkeletonRow extends StatelessWidget {
  const NewsSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 280,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonLoader(width: 60, height: 20, borderRadius: 4),
              SizedBox(height: 12),
              SkeletonLoader(width: double.infinity, height: 16),
              SizedBox(height: 8),
              SkeletonLoader(width: 150, height: 16),
              Spacer(),
              SkeletonLoader(width: 100, height: 12),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key, 
    required this.width, 
    required this.height, 
    this.borderRadius = 8
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = ColorTween(begin: Colors.grey[300], end: Colors.grey[100]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _animation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}