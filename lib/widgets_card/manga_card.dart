import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/home_navbar/mangadetails.dart';
import '../main.dart';

class MangaCard extends StatefulWidget {
  final dynamic manga;
  final bool isPlaceholder;
  final String? userId;

  const MangaCard({Key? key, this.manga, this.isPlaceholder = false, this.userId})
      : super(key: key);

  @override
  _MangaCardState createState() => _MangaCardState();
}

class _MangaCardState extends State<MangaCard> {
  String status = 'Loading...';
  String popularity = '-';
  bool isError = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isPlaceholder) {
      loadFullManga(widget.manga['mal_id']);
    }
  }

  Future<void> loadFullManga(int malId) async {
    setState(() {
      isError = false; // reset error
    });

    var box = await Hive.openBox('fullMangaCache');
    final cacheKey = malId.toString();
    final cachedData = box.get(cacheKey);
    final cachedTimestamp = box.get('$cacheKey-timestamp');

    // Use cache if valid
    if (cachedData != null &&
        cachedTimestamp != null &&
        DateTime.now().millisecondsSinceEpoch - cachedTimestamp < 86400000) {
      final data = Map<String, dynamic>.from(json.decode(cachedData));
      if (!mounted) return;
      setState(() {
        status = data['status'] ?? 'Unknown';
        popularity = data['popularity']?.toString() ?? '-';
      });
      return;
    }

    // Fetch from API
    try {
      final url = 'https://api.jikan.moe/v4/manga/$malId/full';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(response.body)['data']);
        await box.put(cacheKey, json.encode(data));
        await box.put('$cacheKey-timestamp', DateTime.now().millisecondsSinceEpoch);

        if (!mounted) return;
        setState(() {
          status = data['status'] ?? 'Unknown';
          popularity = data['popularity']?.toString() ?? '-';
        });
      } else {
        _handleError(malId);
      }
    } catch (e) {
      _handleError(malId);
    }
  }

  // Retry mechanism
  void _handleError(int malId) {
    if (!mounted) return;
    setState(() => isError = true);

    // Retry after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) loadFullManga(malId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) return _buildPlaceholder();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailsPage(
              mangaId: widget.manga['mal_id'],
              userId: widget.userId ?? '',
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        child: SizedBox(
          width: 140,
          height: 270,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.manga['images']?['jpg']?['image_url'] ?? '',
                  width: 130,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[300], width: 130, height: 160),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 130,
                child: Text(
                  widget.manga['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              isError
                  ? Text(
                      'Retrying...',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    )
                  : AnimatedOpacity(
                      opacity: (status != 'Loading...' || popularity != '-') ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 500),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            children: [
                              const Icon(Icons.trending_up, size: 12, color: Colors.orange),
                              const SizedBox(width: 2),
                              Text(
                                '#$popularity',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
        width: 140,
        height: 270,
        color: Colors.grey[300],
      );

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'publishing':
        return Colors.green;
      case 'finished':
        return Colors.blue;
      case 'on hiatus':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'discontinued':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
