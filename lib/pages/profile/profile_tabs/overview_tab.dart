import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/repository/profile_repository.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/core/providers/settings_provider.dart';

class _RankedPick {
  final TopPickItem item;
  final int originalRank;
  _RankedPick(this.item, this.originalRank);
}

class OverviewTab extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isCurrentUser;

  const OverviewTab({super.key, required this.user, this.isCurrentUser = true});

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> {
  List<_RankedPick> _rotatedPicks = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeList();
    _manageTimer();
  }

  @override
  void didUpdateWidget(OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.topPicks != oldWidget.user.topPicks) {
      _initializeList();
      _manageTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeList() {
    setState(() {
      _rotatedPicks = widget.user.topPicks
          .asMap()
          .entries
          .map((e) => _RankedPick(e.value, e.key + 1))
          .toList();
    });
  }

  void _manageTimer() {
    _timer?.cancel();
    if (_rotatedPicks.length == 5) {
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (!mounted) return;
        setState(() {
          final firstItem = _rotatedPicks.removeAt(0);
          _rotatedPicks.add(firstItem);
        });
      });
    }
  }

  void _navigateToManga(String mangaId) {
    if (mangaId.isEmpty) return;
    final int? id = int.tryParse(mangaId);
    if (id != null) context.push('/manga/$id');
  }

  @override
  Widget build(BuildContext context) {
    final isDataSaver = ref.watch(settingsProvider).value?.isDataSaver ?? false;
    _RankedPick? getPick(int index) =>
        index < _rotatedPicks.length ? _rotatedPicks[index] : null;

    return RepaintBoundary(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopPicksHeader(context),
            const SizedBox(height: 12),
            _buildBentoGrid(getPick, isDataSaver),
            const SizedBox(height: 32),
            _buildSectionHeader("RECENT ACTIVITY", Icons.timeline_rounded),
            const SizedBox(height: 16),
            _buildRecentActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPicksHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionHeader(
            widget.isCurrentUser ? "MY TOP 5 PICKS" : "TOP 5 PICKS",
            Icons.auto_awesome),
        if (widget.isCurrentUser)
          IconButton(
            icon: const Icon(Icons.edit_square, size: 20),
            onPressed: () => context.push('/edit-top-picks/${widget.user.id}'),
          ),
      ],
    );
  }

  Widget _buildBentoGrid(_RankedPick? Function(int) getPick, bool isDataSaver) {
    if (_rotatedPicks.isEmpty) return _buildEmptyState(context);
    final theme = Theme.of(context);

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.dividerColor.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(4, 4),
              blurRadius: 0)
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: _buildAnimatedTile(getPick(0), isDataSaver, isBig: true)),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildAnimatedTile(getPick(1), isDataSaver)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: _buildAnimatedTile(getPick(2), isDataSaver)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildAnimatedTile(getPick(3), isDataSaver)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: _buildAnimatedTile(getPick(4), isDataSaver)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    final activityAsync =
        ref.watch(recentActivityStreamProvider(widget.user.id));

    return activityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Text("Something went wrong"),
      data: (snapshot) {
        final docs = snapshot.docs;
        if (docs.isEmpty)
          return Text("No activity yet.",
              style: TextStyle(color: Theme.of(context).hintColor));

        return Column(
          children: docs.asMap().entries.map((entry) {
            final data = entry.value.data() as Map<String, dynamic>;
            final timestamp = data['updatedAt'] as Timestamp?;
            final status = data['status'] ?? 'Reading';
            final lastCh = data['lastChapterRead']?.toDouble();

            return _buildTimelineItem(
              context,
              time: timeago.format(timestamp?.toDate() ?? DateTime.now()),
              title: data['title'] ?? 'Unknown Manga',
              subtitle: lastCh != null && lastCh > 0
                  ? "Ch. ${lastCh.toString().replaceAll('.0', '')} • $status"
                  : status,
              icon: _getIconForStatus(status),
              color: _getColorForStatus(status),
              isFirst: entry.key == 0,
              isLast: entry.key == docs.length - 1,
              onTap: () => _navigateToManga(data['mangaId'].toString()),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_box_outlined;
      case 'Reading':
        return Icons.menu_book_rounded;
      case 'Dropped':
        return Icons.delete_sweep_outlined;
      case 'On Hold':
        return Icons.pause_presentation_outlined;
      default:
        return Icons.bookmark_border;
    }
  }

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Reading':
        return Colors.blue;
      case 'Dropped':
        return Colors.red;
      case 'On Hold':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                widget.isCurrentUser
                    ? Icons.add_box_outlined
                    : Icons.star_border,
                size: 40,
                color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
                widget.isCurrentUser
                    ? "No favorites yet"
                    : "No top picks selected",
                style: TextStyle(color: theme.hintColor)),
            if (widget.isCurrentUser)
              TextButton(
                onPressed: () =>
                    context.push('/edit-top-picks/${widget.user.id}'),
                child: const Text("Pick Your Top 5"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTile(_RankedPick? rankedPick, bool isDataSaver,
      {bool isBig = false}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _buildMangaTileContent(rankedPick, isDataSaver,
          isBig: isBig, key: ValueKey(rankedPick?.item.mangaId ?? "empty")),
    );
  }

  Widget _buildMangaTileContent(_RankedPick? rankedPick, bool isDataSaver,
      {bool isBig = false, required Key key}) {
    final theme = Theme.of(context);
    if (rankedPick == null) {
      return Container(
          key: key,
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6)));
    }

    final item = rankedPick.item;
    final rank = rankedPick.originalRank;
    int memCacheHeight =
        isDataSaver ? (isBig ? 300 : 150) : (isBig ? 600 : 300);

    return GestureDetector(
      key: key,
      onTap: () => _navigateToManga(item.mangaId),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.coverUrl,
              fit: BoxFit.cover,
              memCacheHeight: memCacheHeight,
              placeholder: (context, url) =>
                  Container(color: theme.colorScheme.surfaceContainerHighest),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: rank == 1
                          ? Colors.amber
                          : theme.dividerColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    if (rank == 1)
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                    if (rank == 1) const SizedBox(width: 2),
                    Text("#$rank",
                        style: TextStyle(
                            color: rank == 1
                                ? Colors.amber
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                  ],
                ),
              ),
            ),
            if (isBig)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8)
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
            if (isBig)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context,
      {required String time,
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      bool isFirst = false,
      bool isLast = false}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                    width: 2,
                    height: 16,
                    color: isFirst ? Colors.transparent : theme.dividerColor),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color, width: 2)),
                  child: Icon(icon, size: 14, color: color),
                ),
                Container(
                    width: 2,
                    height: 40,
                    color: isLast ? Colors.transparent : theme.dividerColor),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 14.0, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14))),
                          const SizedBox(width: 8),
                          Text(time,
                              style: TextStyle(
                                  fontSize: 10, color: theme.hintColor)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
