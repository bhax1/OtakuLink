import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/features/search/domain/entities/search_result_entity.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResultEntity item;
  final VoidCallback onTap;

  const SearchResultTile({super.key, required this.item, required this.onTap});

  // --- OPTIMIZATION: Extracted CPU Logic ---
  // Moving string manipulation out of the build method keeps the UI tree declarative
  static String _formatSubtitle(SearchResultEntity item, bool isUser) {
    String statusDisplay = item.status;
    if (!isUser && statusDisplay != 'Unknown') {
      statusDisplay =
          statusDisplay[0] +
          statusDisplay.substring(1).toLowerCase().replaceAll('_', ' ');
    }

    if (item.chapters != null) {
      return "$statusDisplay • ${item.chapters} Chapters";
    }
    return statusDisplay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = item.type == 'user';
    final double dimensions = isUser ? 45.0 : 65.0;
    final double radius = isUser ? 50.0 : 6.0;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,

        // --- OPTIMIZATION: Removed ClipRRect ---
        leading: Container(
          width: 45,
          height: dimensions,
          decoration: BoxDecoration(
            color: theme.highlightColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: (item.coverImage != null && item.coverImage!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: item.coverImage!,

                  // Prevents OOM crashes by capping RAM allocation
                  memCacheHeight: 150,

                  // Hardware-accelerated clipping
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (context, url) => Icon(
                    isUser ? Icons.person : Icons.book,
                    color: theme.disabledColor,
                  ),
                  errorWidget: (_, _, _) => Icon(
                    isUser ? Icons.person_off : Icons.broken_image,
                    size: 20,
                  ),
                )
              : Icon(
                  isUser ? Icons.person : Icons.book,
                  color: theme.disabledColor,
                ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _formatSubtitle(item, isUser),
          style: theme.textTheme.bodySmall,
        ),
        trailing: (item.score != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(
                    " ${item.score!.toStringAsFixed(1)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
