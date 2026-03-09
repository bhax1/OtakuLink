import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/core/providers/profile_provider.dart';
import 'package:otakulink/features/discussions/domain/entities/discussion_entities.dart';
import 'package:otakulink/features/discussions/presentation/controllers/discussion_controller.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';
import 'reaction_bubble.dart';
import 'report_bottom_sheet.dart';
import 'text_parser.dart';

class DiscussionTile extends ConsumerStatefulWidget {
  final DiscussionComment comment;
  final String? currentUserId;
  final Function(DiscussionComment comment) onReply;
  final Function(String commentId)? onQuoteClick;
  final bool isHighlighted;

  const DiscussionTile({
    super.key,
    required this.comment,
    this.currentUserId,
    required this.onReply,
    this.onQuoteClick,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<DiscussionTile> createState() => _DiscussionTileState();
}

class _DiscussionTileState extends ConsumerState<DiscussionTile> {
  final GlobalKey _reactionButtonKey = GlobalKey();
  final List<String> _reactionTypes = ["👍", "❤️", "😂", "😮", "😢", "😡"];

  Future<void> _handleReaction(String emoji) async {
    if (widget.currentUserId == null) return;

    HapticFeedback.lightImpact();
    await ref
        .read(
          discussionControllerProvider((
            mangaId: widget.comment.mangaId,
            chapterId: widget.comment.chapterId,
          )).notifier,
        )
        .toggleReaction(widget.comment.id, emoji);
  }

  void _showReactionPicker() {
    if (widget.currentUserId == null) return;

    if (_reactionButtonKey.currentContext == null) return;
    final RenderBox renderBox =
        _reactionButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(
      PageRouteBuilder(
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
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    alignment: Alignment.bottomLeft,
                    child: ReactionBubble(
                      emojis: _reactionTypes,
                      currentReaction: widget.comment.reactions
                          .where((r) => r.userId == widget.currentUserId)
                          .map((r) => r.emoji)
                          .firstOrNull,
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
      ),
    );
  }

  Widget _buildQuoteBox(Map<String, dynamic> metadata, ThemeData theme) {
    final qUserId = metadata['userId'];
    final qText = metadata['text'] ?? '...';
    final cleanText = qText.replaceAll(RegExp(r'>!|!<'), '');

    final quoteProfile = ref.watch(userProfileProvider(qUserId));

    return quoteProfile.when(
      loading: () =>
          const SizedBox(height: 20, child: LinearProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        final qUser = user?.username ?? 'Anonymous';
        final isMe = qUserId == widget.currentUserId;
        return GestureDetector(
          onTap: () {
            if (widget.onQuoteClick != null && metadata['id'] != null) {
              widget.onQuoteClick!(metadata['id'] as String);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMe ? "You said:" : "$qUser said:",
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  cleanText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog() async {
    if (widget.currentUserId == null) {
      AppSnackBar.show(
        context,
        "Please log in to report content.",
        type: SnackBarType.warning,
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReportBottomSheet(
        mangaId: widget.comment.mangaId,
        commentId: widget.comment.id,
        chapterId: widget.comment.chapterId,
      ),
    );

    if (result == true && mounted) {
      AppSnackBar.show(
        context,
        "Report submitted. Thank you for keeping the community safe.",
        type: SnackBarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeString = DateFormat(
      'MMM d, yyyy',
    ).format(widget.comment.createdAt);

    final reactions = widget.comment.reactions;
    final myReaction = reactions
        .where((r) => r.userId == widget.currentUserId)
        .map((r) => r.emoji)
        .firstOrNull;

    final reactionCounts = <String, int>{};
    for (var r in reactions) {
      reactionCounts[r.emoji] = (reactionCounts[r.emoji] ?? 0) + 1;
    }
    final sortedReactions = reactionCounts.keys.toList()
      ..sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));
    final topReactions = sortedReactions.take(3).join(" ");

    final isMe = widget.comment.userId == widget.currentUserId;
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
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: widget.comment.avatarUrl != null
                ? CachedNetworkImageProvider(widget.comment.avatarUrl!)
                : null,
            child: widget.comment.avatarUrl == null
                ? Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMe
                          ? "${widget.comment.username} (You)"
                          : widget.comment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      timeString,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (widget.comment.metadata != null)
                  _buildQuoteBox(widget.comment.metadata!, theme),
                TextParser.buildParsedRichText(
                  context,
                  widget.comment.textContent,
                  (_) {},
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      key: _reactionButtonKey,
                      onTap: () => _handleReaction(myReaction ?? "👍"),
                      onLongPress: _showReactionPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: myReaction != null
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                      onTap: () => widget.onReply(widget.comment),
                      child: Text(
                        "Reply",
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _showReportDialog,
                      child: Text(
                        "Report",
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (reactions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          "$topReactions ${reactions.length}",
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
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
