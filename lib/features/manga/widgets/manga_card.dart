import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Changed to StatelessWidget since ref was unused.
// If you uncomment the Data Saver logic, change this back to ConsumerWidget.
class MangaCard extends StatelessWidget {
  final Map<String, dynamic>? manga;
  final bool isPlaceholder;

  const MangaCard({super.key, this.manga, this.isPlaceholder = false});

  static Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final cleanHex = hexColor.startsWith('#')
          ? hexColor.substring(1)
          : hexColor;
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
  Widget build(BuildContext context) {
    if (isPlaceholder || manga == null) return const _MangaCardSkeleton();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Data Extraction
    final titleMap = manga!['title'];
    final String title =
        titleMap?['display'] ??
        titleMap?['english'] ??
        titleMap?['romaji'] ??
        'Unknown';

    final coverMap = manga!['coverImage'];
    final String imageUrl = coverMap?['large'] ?? coverMap?['medium'] ?? '';
    final Color placeholderColor = _parseColor(coverMap?['color']);

    final String statusRaw = manga!['status'] ?? 'UNKNOWN';
    final String status = statusRaw.toString().toUpperCase();

    final rawScore = manga!['averageScore']?.toString() ?? '-';
    final doubleScore = double.tryParse(rawScore);
    final String score = doubleScore != null
        ? (doubleScore / 10).toStringAsFixed(1)
        : rawScore;

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
                // Optimized image rendering with ClipRRect instead of imageBuilder
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          memCacheHeight: 300,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: placeholderColor.withOpacity(0.3),
                            child: Center(
                              child: Icon(Icons.image, color: placeholderColor),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              color: theme.disabledColor,
                            ),
                          ),
                        )
                      : Container(color: colorScheme.surfaceContainerHighest),
                ),
              ),
              if (status != 'UNKNOWN')
                Positioned(
                  top: 8,
                  right: 8,
                  child: _StatusBadge(
                    text: _formatStatus(status),
                    color: _statusColor(status),
                  ),
                ),
              if (score != '-' && score != '0' && score != '0.0')
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _ScoreBadge(score: score),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (year.isNotEmpty && year != 'null')
            Text(
              year,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// --- EXTRACTED CONST WIDGETS FOR PERFORMANCE ---

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors
              .white, // Kept white for contrast against standard badge colors
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.7,
        ), // Standard dark backing for scores
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
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Kept white due to dark backing
            ),
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
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final boneColor = theme.brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 140 / 190,
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 12, width: 100, color: boneColor),
        const SizedBox(height: 4),
        Container(height: 10, width: 60, color: boneColor),
      ],
    );
  }
}
