import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/pages/profile/profile_tabs/library_tab.dart';
import 'package:otakulink/pages/profile/profile_tabs/overview_tab.dart';
import 'package:otakulink/pages/profile/profile_tabs/reviews_tab.dart';
import 'package:otakulink/repository/profile_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: const Center(child: Text("Please login")),
      );
    }

    final profileAsyncValue = ref.watch(userProfileStreamProvider(uid));

    return Scaffold(
      body: profileAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text("Could not load profile.")),
        data: (user) {
          if (user == null)
            return const Center(child: Text("Profile data not found."));

          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            // --- MANGA STYLE BANNER ---
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                border: Border(
                                    bottom: BorderSide(
                                        color: theme.dividerColor
                                            .withOpacity(0.2))),
                              ),
                              child: user.bannerUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: user.bannerUrl,
                                      fit: BoxFit.cover,
                                      memCacheHeight: 400,
                                      placeholder: (context, url) =>
                                          const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.broken_image),
                                    )
                                  : const SizedBox(),
                            ),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FilledButton.tonal(
                                          onPressed: () => context.push(
                                              '/edit-profile',
                                              extra: {'user': user}),
                                          style: FilledButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20),
                                            elevation: 0,
                                          ),
                                          child: const Text("Edit Profile",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5),
                                  ),
                                  Text(
                                    "@${user.username}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (user.bio.isNotEmpty) ...[
                                    Text(
                                      user.bio,
                                      style: const TextStyle(
                                          fontSize: 15, height: 1.5),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Row(
                                    children: [
                                      _buildStat(context, "Following",
                                          user.followingCount, user.id),
                                      const SizedBox(width: 24),
                                      _buildStat(context, "Followers",
                                          user.followerCount, user.id),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // --- SQUARED MANGA VOLUME AVATAR ---
                        Positioned(
                          top: 130,
                          left: 16,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                              image: user.avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(
                                          user.avatarUrl,
                                          maxHeight: 180),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: user.avatarUrl.isEmpty
                                ? Icon(Icons.person,
                                    size: 40,
                                    color: theme.colorScheme.onSurfaceVariant)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: theme.colorScheme.secondary,
                        unselectedLabelColor:
                            theme.colorScheme.onSurface.withOpacity(0.5),
                        indicatorColor: theme.colorScheme.secondary,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: const [
                          Tab(text: "OVERVIEW"),
                          Tab(text: "LIBRARY"),
                          Tab(text: "REVIEWS"),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  OverviewTab(user: user),
                  LibraryTab(userId: user.id),
                  ReviewsTab(userId: user.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(
      BuildContext context, String label, int count, String userId) {
    final theme = Theme.of(context);
    final isFollowers = label.toLowerCase() == "followers";

    return InkWell(
      onTap: () {
        final typeString = isFollowers ? 'followers' : 'following';
        context.push('/follow-list/$userId/$typeString');
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Row(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  // Add 1.0 to the extent to perfectly account for the bottom border
  double get minExtent => _tabBar.preferredSize.height + 1.0;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1.0,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
