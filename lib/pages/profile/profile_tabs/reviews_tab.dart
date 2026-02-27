import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/repository/profile_repository.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:otakulink/core/providers/settings_provider.dart';

class ReviewsTab extends ConsumerStatefulWidget {
  final String userId;
  const ReviewsTab({super.key, required this.userId});

  @override
  ConsumerState<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends ConsumerState<ReviewsTab> {
  int _currentLimit = 20;
  bool _isFetchingMore = false;

  @override
  Widget build(BuildContext context) {
    final profileRepo = ref.watch(profileRepositoryProvider);
    final reviewsStream =
        profileRepo.getReviewsStream(widget.userId, limit: _currentLimit);
    final isDataSaver = ref.watch(settingsProvider).value?.isDataSaver ?? false;

    return StreamBuilder<QuerySnapshot>(
      stream: reviewsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError)
          return const Center(child: Text("Could not load reviews."));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildEmptyState(context);

        final totalDocsFetched = snapshot.data!.docs.length;
        final reviewDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final comment = data['commentary'] as String?;
          return comment != null && comment.trim().isNotEmpty;
        }).toList();

        if (reviewDocs.isEmpty) return _buildEmptyState(context);

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (!_isFetchingMore &&
                scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
              if (totalDocsFetched >= _currentLimit) {
                setState(() {
                  _isFetchingMore = true;
                  _currentLimit += 20;
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) setState(() => _isFetchingMore = false);
                });
              }
            }
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviewDocs.length,
            itemBuilder: (context, index) {
              return _ReviewCard(
                data: reviewDocs[index].data() as Map<String, dynamic>,
                isDataSaver: isDataSaver,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_document,
              size: 50, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text("No reviews written.",
              style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDataSaver;

  const _ReviewCard({required this.data, required this.isDataSaver});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = data['title'] ?? 'Manga';
    final cover = data['imageUrl'];
    final review = data['commentary'] ?? '';
    final timestamp = data['updatedAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(3, 3), // Sharp manga panel shadow
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: CachedNetworkImage(
                      imageUrl: cover ?? '',
                      fit: BoxFit.cover,
                      memCacheHeight: isDataSaver ? 150 : 250,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: (data['rating'] ?? 0).toDouble() / 2,
                            itemBuilder: (context, index) =>
                                const Icon(Icons.star, color: Colors.amber),
                            itemCount: 5,
                            itemSize: 14.0,
                            unratedColor: Colors.amber.withOpacity(0.2),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border.all(color: Colors.amber),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (data['rating'] ?? 0).toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber),
                            ),
                          ),
                          const Spacer(),
                          if (timestamp != null)
                            Text(timeago.format(timestamp.toDate()),
                                style: TextStyle(
                                    fontSize: 10, color: theme.hintColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1)),
            Text(
              review,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
