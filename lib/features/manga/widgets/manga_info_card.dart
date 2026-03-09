import 'package:flutter/material.dart';

import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';
import 'package:otakulink/features/manga/domain/entities/manga_stats_entity.dart';

class MangaInfoCard extends StatelessWidget {
  final MangaDetailEntity details;
  final MangaStatsEntity? stats;

  const MangaInfoCard({super.key, required this.details, this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = details.manga.averageScore;

    final String appRating = stats != null && stats!.averageRating > 0
        ? "${stats!.averageRating.toStringAsFixed(1)} / 10.0"
        : "N/A";

    final String anilistScore = avg != null ? "${(avg * 10).toInt()}%" : "N/A";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildRow(context, 'App Rating', appRating),
          _buildRow(context, 'AniList Score', anilistScore),
          if (stats != null && stats!.bookmarkCount > 0)
            _buildRow(context, 'Bookmarks', stats!.bookmarkCount.toString()),
          _buildRow(context, 'Status', details.manga.status),
          _buildRow(
            context,
            'Chapters',
            details.manga.chapters?.toString() ?? 'Ongoing',
          ),
          _buildRow(context, 'Type', details.manga.type),
          _buildRow(context, 'Released', _formatDate(details.manga.year)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String yearStr) {
    if (yearStr == '-') return '?';
    return yearStr;
  }
}
