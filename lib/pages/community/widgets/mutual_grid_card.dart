import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/repository/chat_repository.dart';
import 'package:otakulink/repository/profile_repository.dart';

class MutualGridCard extends ConsumerWidget {
  final String userId;
  final String searchQuery;

  const MutualGridCard({
    Key? key,
    required this.userId,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatRepo = ref.watch(chatRepositoryProvider);
    final userAsyncValue = ref.watch(userProfileFutureProvider(userId));

    return userAsyncValue.when(
      loading: () => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
          onTap: () => context
              .push('/profile/$username', extra: {'targetUserId': userId}),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: photoURL.isNotEmpty
                        ? Image.network(photoURL, fit: BoxFit.cover)
                        : Image.asset('assets/pic/default_avatar.png',
                            fit: BoxFit.cover),
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
                              FirebaseAuth.instance.currentUser?.uid;
                          if (currentUid == null) return;

                          await chatRepo.ensureConversationExists(
                              friendId: userId);
                          final chatId = currentUid.compareTo(userId) <= 0
                              ? 'conversation_${currentUid}_$userId'
                              : 'conversation_${userId}_$currentUid';

                          if (context.mounted) {
                            context.push(
                              '/message/$chatId',
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
