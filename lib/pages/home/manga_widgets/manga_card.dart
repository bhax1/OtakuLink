import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/home/manga_details_page.dart';

class MangaCard extends StatelessWidget {
  final dynamic manga;
  final bool isPlaceholder;
  final String? userId;

  const MangaCard({
    Key? key, 
    this.manga, 
    this.isPlaceholder = false, 
    this.userId
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isPlaceholder) return _buildPlaceholder();

    final String title = manga['title']['display'] ?? manga['title']['english'] ?? 'Unknown';
    final String imageUrl = manga['coverImage']?['large'] ?? '';
    final String colorHex = manga['coverImage']?['color'] ?? '#cccccc';
    final Color placeholderColor = _parseColor(colorHex);

    final String status = (manga['status'] ?? 'UNKNOWN').toString().toUpperCase();
    final String score = manga['averageScore']?.toString() ?? '-';
    final String year = manga['year']?.toString() ?? '';
    final int id = manga['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => MangaDetailsPage(mangaId: id, userId: userId ?? ''),
        ));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGE CARD (Responsive AspectRatio)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 140 / 190, // Maintain the original shape (approx 0.73)
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover, // Important: Fill the space
                    placeholder: (context, url) => Container(
                      color: placeholderColor.withOpacity(0.3),
                      child: Center(child: Icon(Icons.image, color: placeholderColor)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              
              // Status Badge
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),

              // Score Badge
              if (score != '-' && score != '0')
                Positioned(
                  bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          (double.tryParse(score) != null) ? (double.parse(score) / 10).toStringAsFixed(1) : score,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // 2. TITLE
          SizedBox(
            height: 36,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 3. YEAR
          if (year.isNotEmpty && year != '-')
            Text(
              year,
              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 140 / 190,
          child: Container(
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 12, width: 100, color: Colors.grey[300]),
        const SizedBox(height: 4),
        Container(height: 10, width: 60, color: Colors.grey[300]),
      ],
    );
  }

  // ... (Keep helper methods _parseColor, _formatStatus, _statusColor exactly as they were) ...
  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) return Color(int.parse('0xFF$hexColor'));
    } catch (e) {}
    return Colors.grey;
  }

  String _formatStatus(String status) {
    if (status == 'RELEASING') return 'ONGOING';
    if (status == 'NOT_YET_RELEASED') return 'UPCOMING';
    return status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RELEASING': case 'PUBLISHING': return Colors.green;
      case 'FINISHED': return Colors.blueAccent;
      case 'HIATUS': case 'ON_HIATUS': return Colors.orange;
      case 'CANCELLED': return Colors.red;
      case 'NOT_YET_RELEASED': return Colors.purpleAccent;
      default: return Colors.grey;
    }
  }
}