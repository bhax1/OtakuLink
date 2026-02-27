import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/services/discussion_service.dart';
import 'package:otakulink/services/user_service.dart';
import 'reaction_bubble.dart';
import 'text_parser.dart';

class DiscussionTile extends ConsumerStatefulWidget {
  final String commentId;
  final int mangaId;
  final Map<String, dynamic> data;
  final String currentUserId;
  final Function(String id, String user, String userId, String text) onReply;
  final Function(String targetId) onQuoteClick;
  final Function(String targetUserId, String commentId, String emoji)?
      onReactionSent;
  final List<QueryDocumentSnapshot> allCommentsSnapshot;
  final bool isHighlighted;

  const DiscussionTile({
    Key? key,
    required this.commentId,
    required this.mangaId,
    required this.data,
    required this.currentUserId,
    required this.onReply,
    required this.onQuoteClick,
    required this.allCommentsSnapshot,
    this.onReactionSent,
    this.isHighlighted = false,
  }) : super(key: key);

  @override
  ConsumerState<DiscussionTile> createState() => _DiscussionTileState();
}

class _DiscussionTileState extends ConsumerState<DiscussionTile> {
  final DiscussionService _commentsService = DiscussionService();
  final GlobalKey _reactionButtonKey = GlobalKey();
  final List<String> _reactionTypes = ["👍", "❤️", "😂", "😮", "😢", "😡"];

  void _navigateToProfile(String? userId, String username) {
    if (userId == null || userId.isEmpty || userId == widget.currentUserId) {
      return;
    }
    context.push('/profile/$username', extra: {'targetUserId': userId});
  }

  Future<void> _handleReaction(String emoji) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final currentReactions =
        widget.data['reactions'] as Map<String, dynamic>? ?? {};
    final String? previousEmoji = currentReactions[widget.currentUserId];

    await _commentsService.toggleReaction(
      mangaId: widget.mangaId,
      commentId: widget.commentId,
      userId: widget.currentUserId,
      emoji: emoji,
    );

    if ((previousEmoji == null || previousEmoji != emoji) &&
        widget.onReactionSent != null) {
      widget.onReactionSent!(widget.data['userId'], widget.commentId, emoji);
    }
  }

  void _showReactionPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_reactionButtonKey.currentContext == null) return;

    final RenderBox renderBox =
        _reactionButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: buttonPosition.dy - 65,
              left: 20,
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                      parent: animation, curve: Curves.easeOutBack),
                  alignment: Alignment.bottomLeft,
                  child: ReactionBubble(
                    emojis: _reactionTypes,
                    currentReaction:
                        (widget.data['reactions'] ?? {})[widget.currentUserId],
                    onEmojiSelected: (emoji) {
                      Navigator.pop(context);
                      _handleReaction(emoji);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ));
  }

  void _handleMentionClick(String username) async {
    String cleanName = username.replaceAll('@', '');
    final targetUserId =
        await ref.read(userServiceProvider).getUserIdByUsername(cleanName);
    if (targetUserId != null) {
      _navigateToProfile(targetUserId, username);
    }
  }

  Widget _buildQuoteBox(Map<String, dynamic> replyContext, ThemeData theme) {
    final qId = replyContext['id'];
    final qUserId = replyContext['userId'];
    final qText = replyContext['text'] ?? '...';
    final cleanText = qText.replaceAll(RegExp(r'>!|!<'), '');

    final quoteProfile = ref.watch(userProfileProvider(qUserId));

    return quoteProfile.when(
      loading: () => const SizedBox(
          height: 40, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        final qUser = user?.username ?? 'Anonymous';
        final isMe = qUserId == widget.currentUserId;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: Border(
                left: BorderSide(
                    color: theme.colorScheme.outlineVariant, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (qId != null) widget.onQuoteClick(qId);
                },
                child: Row(
                  children: [
                    Icon(Icons.format_quote,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: isMe
                          ? null
                          : () => _navigateToProfile(qUserId, qUser),
                      child: Text(
                        isMe ? "You said:" : "$qUser said:",
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: isMe
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_upward,
                        size: 10, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(cleanText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontStyle: FontStyle.italic))
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentUserId = widget.data['userId'];

    // Core Fix: Watch the profile provider here
    final profileAsync = ref.watch(userProfileProvider(commentUserId));

    return profileAsync.when(
      loading: () =>
          _buildTileLayout(context, theme, 'Loading...', null, isLoading: true),
      error: (err, _) => _buildTileLayout(context, theme, '[Error]', null),
      data: (user) => _buildTileLayout(
          context, theme, user?.username ?? '[Deleted User]', user?.avatarUrl),
    );
  }

  Widget _buildTileLayout(
      BuildContext context, ThemeData theme, String userName, String? avatarUrl,
      {bool isLoading = false}) {
    final rawText = widget.data['textContent'] ?? '';
    final ts = widget.data['timestamp'] as Timestamp?;
    final timeString =
        ts != null ? DateFormat('MMM d, yyyy').format(ts.toDate()) : '...';
    final reactions = widget.data['reactions'] as Map<String, dynamic>? ?? {};
    final myReaction = reactions[widget.currentUserId];

    final reactionCounts = <String, int>{};
    reactions.values
        .forEach((r) => reactionCounts[r] = (reactionCounts[r] ?? 0) + 1);
    final sortedReactions = reactionCounts.keys.toList()
      ..sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));
    final topReactions = sortedReactions.take(3).join(" ");
    final totalReactions = reactions.length;
    final replyContext = widget.data['replyContext'] as Map<String, dynamic>?;

    final commentUserId = widget.data['userId'];
    final isMe = commentUserId == widget.currentUserId;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? isDark
                ? theme.colorScheme.secondaryContainer.withOpacity(0.3)
                : theme.colorScheme.primaryContainer.withOpacity(0.3)
            : Colors.transparent,
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            // Logic: Only allow tap if NOT loading and NOT the current user
            onTap: (isLoading || isMe)
                ? null
                : () => _navigateToProfile(commentUserId, userName),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.person, color: Colors.grey),
                      )
                    : Icon(Icons.person,
                        color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      // Same logic for the username text
                      onTap: (isLoading || isMe)
                          ? null
                          : () => _navigateToProfile(commentUserId, userName),
                      child: Text(isMe ? "$userName (You)" : userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Text(timeString,
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                if (replyContext != null) _buildQuoteBox(replyContext, theme),
                TextParser.buildParsedRichText(
                    context, rawText, _handleMentionClick),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      key: _reactionButtonKey,
                      onTap: () => _handleReaction(myReaction ?? "👍"),
                      onLongPress: _showReactionPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                            color: myReaction != null
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          myReaction ?? "Like",
                          style: TextStyle(
                            fontSize: myReaction != null ? 16 : 12,
                            fontWeight: FontWeight.bold,
                            color: myReaction != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () => widget.onReply(widget.commentId, userName,
                              widget.data['userId'], rawText),
                      child: Text("Reply",
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    if (totalReactions > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        child: Text("$topReactions $totalReactions",
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface)),
                      )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
