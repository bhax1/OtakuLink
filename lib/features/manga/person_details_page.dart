import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/features/manga/widgets/expandable_bio.dart';
import 'package:otakulink/core/services/anilist_service.dart';
import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';
import 'package:otakulink/features/manga/data/models/manga_models.dart';
import 'widgets/person_header.dart';

class PersonDetailsPage extends ConsumerStatefulWidget {
  final int id;
  final bool isStaff;
  final Object heroTag;

  const PersonDetailsPage({
    super.key,
    required this.id,
    required this.isStaff,
    required this.heroTag,
  });

  @override
  ConsumerState<PersonDetailsPage> createState() => _PersonDetailsPageState();
}

class _PersonDetailsPageState extends ConsumerState<PersonDetailsPage> {
  late Future<PersonEntity?> _personFuture;

  @override
  void initState() {
    super.initState();
    // Using the legacy service temporarily while the repository integration for Person details is completed
    _personFuture = AniListService.getPersonDetails(widget.id, widget.isStaff)
        .then((map) {
          if (map == null) return null;
          return widget.isStaff
              ? PersonModel.fromAniListStaff(map)
              : PersonModel.fromAniListCharacter(map);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<PersonEntity?>(
        future: _personFuture,
        builder: (context, snapshot) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _getBody(context, snapshot),
          );
        },
      ),
    );
  }

  Widget _getBody(BuildContext context, AsyncSnapshot<PersonEntity?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildSkeleton(context);
    }

    if (snapshot.hasError || !snapshot.hasData) {
      return Scaffold(
        key: const ValueKey('error'),
        appBar: AppBar(),
        body: const Center(child: Text("Could not load details")),
      );
    }

    final data = snapshot.data!;

    // --- APPLY DATA SAVER LOGIC ---
    final String imageUrl = data.image ?? '';

    return CustomScrollView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                PersonHeader(
                  imageUrl: imageUrl,
                  fullName: data.name,
                  nativeName: data.nativeName,
                  heroTag: widget.heroTag,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: !widget.isStaff
                      ? [
                          _buildBadge(context, data.age),
                          _buildBadge(context, data.gender),
                          _buildBadge(context, data.bloodType),
                        ]
                      : [
                          _buildBadge(
                            context,
                            data.role,
                          ), // Acts as primary occupation
                          _buildBadge(context, data.homeTown),
                          _buildBadge(context, data.yearsActive),
                        ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                ExpandableBio(
                  rawBio: data.description ?? "No description available.",
                  isStaff: widget.isStaff,
                  onCharacterTap: (charId) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonDetailsPage(
                        id: charId,
                        isStaff: false,
                        heroTag: 'nested_$charId',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String? label) {
    if (label == null || label.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leadingWidth: 100,
      leading: Row(
        children: [
          BackButton(color: Theme.of(context).iconTheme.color),
          IconButton(
            icon: Icon(
              Icons.home_filled,
              color: Theme.of(context).iconTheme.color,
            ),
            tooltip: "Back to Home",
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final skeletonColor = theme.colorScheme.surfaceContainerHighest.withOpacity(
      0.4,
    );

    return CustomScrollView(
      key: const ValueKey('loading'),
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 260,
                  width: 180,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 220,
                  height: 28,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 18,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: 80,
                      height: 38,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    6,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        width: index == 5 ? 150 : double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
