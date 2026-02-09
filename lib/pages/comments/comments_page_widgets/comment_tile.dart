import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/theme.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
import '../comments_services/comments_service.dart';
import '../comments_services/text_parser.dart';
import 'reaction_bubble.dart';

class MangaPanelTile extends StatefulWidget {
  final String commentId;
  final int mangaId;
  final Map<String, dynamic> data;
  final String currentUserId;
  final Function(String id, String user, String userId, String text) onReply;
  final Function(String targetId) onQuoteClick;
  final Function(String targetUserId, String commentId, String emoji)? onReactionSent; 
  final List<QueryDocumentSnapshot> allCommentsSnapshot;
  final bool isHighlighted;

  const MangaPanelTile({
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
  State<MangaPanelTile> createState() => _MangaPanelTileState();
}

class _MangaPanelTileState extends State<MangaPanelTile> {
  final CommentsService _commentsService = CommentsService();
  final GlobalKey _reactionButtonKey = GlobalKey();
  final List<String> _reactionTypes = ["👍", "❤️", "😂", "😮", "😢", "😡"];

  void _navigateToProfile(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfilePage(userId: userId)));
    }
  }

  Future<void> _handleReaction(String emoji) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final currentReactions = widget.data['reactions'] as Map<String, dynamic>? ?? {};
    final String? previousEmoji = currentReactions[widget.currentUserId];
    
    // Determine if this is a new reaction or a change for notification purposes
    final bool isNewReaction = previousEmoji == null;
    final bool isChangedReaction = previousEmoji != null && previousEmoji != emoji;

    await _commentsService.toggleReaction(
      mangaId: widget.mangaId,
      commentId: widget.commentId,
      userId: widget.currentUserId,
      emoji: emoji,
    );

    if ((isNewReaction || isChangedReaction) && widget.onReactionSent != null) {
      widget.onReactionSent!(widget.data['userId'], widget.commentId, emoji);
    }
  }

  void _showReactionPicker() {
    FocusScope.of(context).unfocus();
    if (_reactionButtonKey.currentContext == null) return;
    
    final RenderBox renderBox = _reactionButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                top: buttonPosition.dy - 65, 
                left: 20, 
                child: FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    alignment: Alignment.bottomLeft,
                    child: ReactionBubble(
                      emojis: _reactionTypes,
                      currentReaction: (widget.data['reactions'] ?? {})[widget.currentUserId],
                      onEmojiSelected: (emoji) {
                        Navigator.of(context).pop();
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

  void _handleMentionClick(String username) {
    String cleanName = username.replaceAll('@', '');
    try {
      final userComment = widget.allCommentsSnapshot.firstWhere(
        (doc) => (doc.data() as Map<String, dynamic>)['username'] == cleanName,
      );
      final userId = (userComment.data() as Map<String, dynamic>)['userId'];
      _navigateToProfile(userId);
    } catch (e) { 
      // User not found in loaded comments
    }
  }

  Widget _buildQuoteBox(Map<String, dynamic> data) {
    final qUser = data['username'] ?? '???';
    final qText = data['text'] ?? '...';
    final qId = data['id'];
    final cleanText = qText.replaceAll(RegExp(r'>!|!<'), '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(left: BorderSide(color: Colors.grey[400]!, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () { if (qId != null) widget.onQuoteClick(qId); },
            child: Row(
              children: [
                Icon(Icons.format_quote, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text("$qUser said:", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_upward, size: 10, color: Colors.grey[500]),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(cleanText, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontStyle: FontStyle.italic))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.data['username'] ?? 'Anonymous';
    final rawText = widget.data['text'] ?? '';
    final photoUrl = widget.data['userPhoto'];
    final ts = widget.data['timestamp'] as Timestamp?;
    final timeString = ts != null ? DateFormat('MMM d, yyyy').format(ts.toDate()) : '...';

    final reactions = widget.data['reactions'] as Map<String, dynamic>? ?? {};
    final myReaction = reactions[widget.currentUserId];

    // Calculate reactions stats
    final reactionCounts = <String, int>{};
    reactions.values.forEach((r) => reactionCounts[r] = (reactionCounts[r] ?? 0) + 1);
    final sortedReactions = reactionCounts.keys.toList()
      ..sort((a, b) => reactionCounts[b]!.compareTo(reactionCounts[a]!));
    final topReactions = sortedReactions.take(3).join(" ");
    final totalReactions = reactions.length;

    final replyContext = widget.data['replyContext'] as Map<String, dynamic>?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isHighlighted ? const Color(0xFFFFF9C4) : Colors.transparent, 
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToProfile(widget.data['userId']),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              child: ClipOval(
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        placeholder: (context, url) => Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                      )
                    : const Icon(Icons.person, color: Colors.grey),
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
                      onTap: () => _navigateToProfile(widget.data['userId']),
                      child: Text(userName,
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                    Text(timeString,
                        style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                if (replyContext != null) _buildQuoteBox(replyContext),
                
                // Using TextParser Service Here
                TextParser.buildParsedRichText(
                  rawText,
                  _handleMentionClick,
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      key: _reactionButtonKey,
                      onTap: () => _handleReaction(myReaction ?? "👍"),
                      onLongPress: _showReactionPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: myReaction != null ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Row(
                          children: [
                            Text(
                              myReaction ?? "Like",
                              style: TextStyle(
                                fontSize: myReaction != null ? 16 : 12,
                                fontWeight: FontWeight.bold,
                                color: myReaction != null
                                    ? AppColors.primary
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => widget.onReply(
                          widget.commentId, 
                          userName, 
                          widget.data['userId'],
                          rawText
                      ),
                      child: Text("Reply",
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    if (totalReactions > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                          border: Border.all(color: Colors.grey[100]!),
                        ),
                        child: Text("$topReactions $totalReactions",
                            style: const TextStyle(fontSize: 11)),
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