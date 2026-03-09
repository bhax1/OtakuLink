import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/features/chat/data/repositories/chat_repository.dart';
import 'package:otakulink/features/profile/data/repositories/profile_repository.dart';

class MutualGridCard extends ConsumerWidget {
  final String userId;
  final String searchQuery;

  const MutualGridCard({
    super.key,
    required this.userId,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatRepo = ref.watch(chatRepositoryProvider);
    final userAsyncValue = ref.watch(userProfileFutureProvider(userId));

    return userAsyncValue.when(
      loading: () => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final username = user.username;
        final photoURL = user.avatarUrl;

        if (searchQuery.isNotEmpty &&
            !username.toLowerCase().contains(searchQuery)) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => context.push(
            '/profile/$username',
            extra: {'targetUserId': userId},
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: photoURL.isNotEmpty
                        ? Image.network(photoURL, fit: BoxFit.cover)
                        : Image.asset(
                            'assets/pic/default_avatar.png',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final currentUid =
                              Supabase.instance.client.auth.currentUser?.id;
                          if (currentUid == null) return;

                          await chatRepo.ensureConversationExists(
                            friendId: userId,
                          );

                          // With Supabase, we should ideally fetch the exact generated Room ID
                          // instead of guessing the string format. Currently, we can rely on an RPC
                          // or just fetch it here. For UI purposes, we will pass the friendId
                          // and handle the lookup in the next page, or perform the RPC lookup here.

                          // Quick RPC lookup to get the exact room UUID:
                          final response = await Supabase.instance.client.rpc(
                            'get_direct_chat_room',
                            params: {'p1': currentUid, 'p2': userId},
                          );

                          if (response != null && context.mounted) {
                            context.push(
                              '/message/$response',
                              extra: <String, dynamic>{
                                'title': username,
                                'profilePic': photoURL,
                                'isGroup': false,
                              },
                            );
                          }
                        },
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
