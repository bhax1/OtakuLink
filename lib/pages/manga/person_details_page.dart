import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/pages/manga/manga_widgets/expandable_bio.dart';
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/core/providers/settings_provider.dart';
import 'manga_details_widgets/person_header.dart';

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
  late Future<Map<String, dynamic>?> _personFuture;

  @override
  void initState() {
    super.initState();
    _personFuture = AniListService.getPersonDetails(widget.id, widget.isStaff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
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

  Widget _getBody(
      BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
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
    final isDataSaver = ref.watch(settingsProvider).value?.isDataSaver ?? false;
    final String imageUrl = isDataSaver
        ? (data['image']['medium'] ?? data['image']['large'] ?? '')
        : (data['image']['large'] ?? data['image']['medium'] ?? '');

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
                  fullName: data['name']['full'],
                  nativeName: data['name']['native'],
                  heroTag: widget.heroTag,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: !widget.isStaff
                      ? [
                          _buildBadge(context, data['age']),
                          _buildBadge(context, data['gender']),
                          _buildBadge(context, data['bloodType']),
                        ]
                      : [
                          _buildBadge(context, data['primaryOccupations']),
                          _buildBadge(context, data['homeTown']),
                          _buildBadge(context, data['yearsActive']),
                        ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                ExpandableBio(
                  rawBio: data['description'] ?? "No description available.",
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
            icon: Icon(Icons.home_filled,
                color: Theme.of(context).iconTheme.color),
            tooltip: "Back to Home",
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final skeletonColor =
        theme.colorScheme.surfaceContainerHighest.withOpacity(0.4);

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
                          )),
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
                          )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, dynamic value) {
    if (value == null || value.toString().isEmpty)
      return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value.toString(),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
