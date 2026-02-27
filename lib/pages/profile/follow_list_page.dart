import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/pages/profile/profile_widgets/follow_button.dart';
import 'package:otakulink/repository/follow_repository.dart';

enum FollowListType { followers, following }

class FollowListPage extends ConsumerWidget {
  final String userId;
  final FollowListType listType;

  const FollowListPage({
    super.key,
    required this.userId,
    required this.listType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFollowers = listType == FollowListType.followers;
    final title = isFollowers ? "Followers" : "Following";

    final asyncList = isFollowers
        ? ref.watch(followersListProvider(userId))
        : ref.watch(followingListProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
        ),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            const Center(child: Text("Failed to load users.")),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_alt_outlined,
                      size: 60, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    isFollowers
                        ? "No followers yet."
                        : "Not following anyone yet.",
                    style: TextStyle(
                        color: theme.hintColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      offset: const Offset(2, 2),
                      blurRadius: 0, // Sharp drop shadow
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      image: user.avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(user.avatarUrl,
                                  maxHeight: 120),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user.avatarUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    user.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    "@${user.username}",
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () {
                    context.push(
                      '/profile/${user.username}',
                      extra: {'targetUserId': user.id},
                    );
                  },
                  trailing: FollowButton(targetUserId: user.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
