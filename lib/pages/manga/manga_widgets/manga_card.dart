import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/core/providers/settings_provider.dart';

class MangaCard extends ConsumerWidget {
  final Map<String, dynamic>? manga;
  final bool isPlaceholder;

  const MangaCard({
    Key? key,
    this.manga,
    this.isPlaceholder = false,
  }) : super(key: key);

  static Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final cleanHex =
          hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
      if (cleanHex.length == 6) {
        return Color(int.parse(cleanHex, radix: 16) + 0xFF000000);
      }
    } catch (_) {}
    return Colors.grey;
  }

  static String _formatStatus(String status) {
    if (status == 'RELEASING') return 'ONGOING';
    if (status == 'NOT_YET_RELEASED') return 'UPCOMING';
    return status;
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'RELEASING':
      case 'PUBLISHING':
        return Colors.green;
      case 'FINISHED':
        return Colors.blueAccent;
      case 'HIATUS':
      case 'ON_HIATUS':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      case 'NOT_YET_RELEASED':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Add WidgetRef
    if (isPlaceholder || manga == null) return const _MangaCardSkeleton();

    final titleMap = manga!['title'];
    final String title = titleMap?['display'] ??
        titleMap?['english'] ??
        titleMap?['romaji'] ??
        'Unknown';

    // --- DATA SAVER LOGIC ---
    final isDataSaver = ref.watch(settingsProvider).value?.isDataSaver ?? false;
    final coverMap = manga!['coverImage'];

    // Prioritize medium if Data Saver is on, otherwise prioritize large
    final String imageUrl = isDataSaver
        ? (coverMap?['medium'] ?? coverMap?['large'] ?? '')
        : (coverMap?['large'] ?? coverMap?['medium'] ?? '');

    final Color placeholderColor = _parseColor(coverMap?['color']);

    final String statusRaw = manga!['status'] ?? 'UNKNOWN';
    final String status = statusRaw.toString().toUpperCase();

    final rawScore = manga!['averageScore']?.toString() ?? '-';
    final doubleScore = double.tryParse(rawScore);
    final String score =
        doubleScore != null ? (doubleScore / 10).toStringAsFixed(1) : rawScore;

    final String year = manga!['startDate']?['year']?.toString() ?? '';
    final int id = manga!['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        if (id != 0) context.push('/manga/$id');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 140 / 190,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        // Lower the memCacheHeight even further if Data Saver is active
                        memCacheHeight: isDataSaver ? 200 : 300,
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            color: placeholderColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                              child:
                                  Icon(Icons.image, color: placeholderColor)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
              ),
              if (status != 'UNKNOWN')
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildBadge(
                    text: _formatStatus(status),
                    color: _statusColor(status),
                  ),
                ),
              if (score != '-' && score != '0' && score != '0.0')
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _buildScoreBadge(score),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (year.isNotEmpty && year != 'null')
            Text(
              year,
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  // ... [_buildBadge, _buildScoreBadge remain exactly as they were]
  Widget _buildBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildScoreBadge(String score) {
    return Container(
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
            score,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MangaCardSkeleton extends StatelessWidget {
  const _MangaCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 140 / 190,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 12, width: 100, color: Colors.grey[300]),
        const SizedBox(height: 4),
        Container(height: 10, width: 60, color: Colors.grey[300]),
      ],
    );
  }
}
