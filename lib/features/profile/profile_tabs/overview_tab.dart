import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/features/profile/domain/entities/profile_entities.dart';

class _RankedPick {
  final TopPickEntity item;
  final int originalRank;
  _RankedPick(this.item, this.originalRank);
}

class OverviewTab extends ConsumerStatefulWidget {
  final ProfileEntity user;
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
    const bool isDataSaver = false;
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
            _buildSectionHeader("MANGA STATS", Icons.donut_large_rounded),
            const SizedBox(height: 16),
            _buildStatsGrid(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;

    final stats = [
      {'label': 'Reading', 'count': user.reading, 'color': Colors.blue},
      {'label': 'Completed', 'count': user.completed, 'color': Colors.green},
      {'label': 'On Hold', 'count': user.onHold, 'color': Colors.orange},
      {'label': 'Dropped', 'count': user.dropped, 'color': Colors.red},
      {'label': 'Planned', 'count': user.planned, 'color': Colors.blueGrey},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 70,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        final label = stat['label'] as String;
        final count = stat['count'] as int;
        final color = stat['color'] as Color;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopPicksHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionHeader(
          widget.isCurrentUser ? "MY TOP 5 PICKS" : "TOP 5 PICKS",
          Icons.auto_awesome,
        ),
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
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _buildAnimatedTile(getPick(0), isDataSaver, isBig: true),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildAnimatedTile(getPick(1), isDataSaver),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAnimatedTile(getPick(2), isDataSaver),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildAnimatedTile(getPick(3), isDataSaver),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAnimatedTile(getPick(4), isDataSaver),
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isCurrentUser ? Icons.add_box_outlined : Icons.star_border,
              size: 40,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              widget.isCurrentUser
                  ? "No favorites yet"
                  : "No top picks selected",
              style: TextStyle(color: theme.hintColor),
            ),
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

  Widget _buildAnimatedTile(
    _RankedPick? rankedPick,
    bool isDataSaver, {
    bool isBig = false,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _buildMangaTileContent(
        rankedPick,
        isDataSaver,
        isBig: isBig,
        key: ValueKey(rankedPick?.item.mangaId ?? "empty"),
      ),
    );
  }

  Widget _buildMangaTileContent(
    _RankedPick? rankedPick,
    bool isDataSaver, {
    bool isBig = false,
    required Key key,
  }) {
    final theme = Theme.of(context);
    if (rankedPick == null) {
      return Container(
        key: key,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final item = rankedPick.item;
    final rank = rankedPick.originalRank;
    int memCacheHeight = isDataSaver
        ? (isBig ? 300 : 150)
        : (isBig ? 600 : 300);

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
                        : theme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    if (rank == 1)
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                    if (rank == 1) const SizedBox(width: 2),
                    Text(
                      "#$rank",
                      style: TextStyle(
                        color: rank == 1
                            ? Colors.amber
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
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
                        Colors.black.withValues(alpha: 0.8),
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
                    height: 1.2,
                  ),
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
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
