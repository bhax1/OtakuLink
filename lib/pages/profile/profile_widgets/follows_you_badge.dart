import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/repository/follow_repository.dart';

class FollowsYouBadge extends ConsumerWidget {
  final String targetUserId;

  const FollowsYouBadge({super.key, required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowedByAsync = ref.watch(isFollowedByProvider(targetUserId));

    return isFollowedByAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isFollowedBy) {
        if (!isFollowedBy) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2)),
          ),
          child: Text(
            "Follows you",
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        );
      },
    );
  }
}
