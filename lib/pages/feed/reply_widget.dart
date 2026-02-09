import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/pages/feed/feed_services/user_cache.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
import 'package:otakulink/pages/feed/reaction_helper.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReplyWidget extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String postId;
  final int depth;
  final Function(String, String?) onReplyTap;
  final Function(int) onTabChange;

  const ReplyWidget({
    super.key, 
    required this.doc, 
    required this.postId, 
    required this.depth, 
    required this.onReplyTap, 
    required this.onTabChange
  });

  // --- REACTION LOGIC ---
  Future<void> _handleReaction(String type, String? current) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('feeds')
        .doc(postId)
        .collection('replies')
        .doc(doc.id);

    if (current == type) {
      await ref.update({'reactions.$uid': FieldValue.delete()});
    } else {
      await ref.update({'reactions.$uid': type});
    }
  }

  // --- UPDATED: EMOJI MENU ---
  void _showReactionMenu(BuildContext context, String? current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEmojiOption(context, ReactionTypes.like),
            _buildEmojiOption(context, ReactionTypes.love),
            _buildEmojiOption(context, ReactionTypes.haha),
            _buildEmojiOption(context, ReactionTypes.wow),
            _buildEmojiOption(context, ReactionTypes.sad),
            _buildEmojiOption(context, ReactionTypes.angry),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiOption(BuildContext context, String type) {
    return GestureDetector(
      onTap: () {
        _handleReaction(type, null);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          ReactionTypes.getEmoji(type),
          style: const TextStyle(fontSize: 28), // Large Emoji
        ),
      ),
    );
  }

  void _handleProfileTap(BuildContext context, String targetUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == targetUserId) {
      Navigator.pop(context);
      onTabChange(4); 
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfilePage(userId: targetUserId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data['userId'] as String;
    
    // Reaction Data
    final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final myReaction = reactions[myId] as String?;

    return StreamBuilder<Map<String, dynamic>>(
      stream: UserCache.streamUser(userId),
      builder: (context, snapshot) {
        final user = snapshot.data ?? {};
        final username = user['username'] ?? 'User';
        final photoUrl = user['photoURL'] ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: depth > 0 ? Border(left: BorderSide(color: Colors.grey.shade300, width: 2)) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: () => _handleProfileTap(context, userId),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                ),
              ),
              const SizedBox(width: 10),
              
              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Name + Time
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _handleProfileTap(context, userId),
                          child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        if (data['timestamp'] != null)
                          Text(
                            timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'en_short'), 
                            style: const TextStyle(color: Colors.grey, fontSize: 11)
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    
                    // Comment Text
                    Text(data['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.3)),
                    
                    const SizedBox(height: 6),
                    
                    // Action Row
                    Row(
                      children: [
                        // Reaction Button
                        GestureDetector(
                          onTap: () => _handleReaction(ReactionTypes.like, myReaction),
                          onLongPress: () => _showReactionMenu(context, myReaction),
                          child: Row(
                            children: [
                              if (myReaction != null)
                                Text(ReactionTypes.getEmoji(myReaction), style: const TextStyle(fontSize: 16))
                              else
                                const Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey),
                              
                              // Optional: Add label "Like" if not reacted, or count if reacted
                              if (myReaction == null && reactions.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text("Like", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                        
                        if (reactions.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                            child: Text(
                              "${reactions.length}", 
                              style: TextStyle(fontSize: 10, color: Colors.grey[800], fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],

                        const SizedBox(width: 16),

                        // Reply Button
                        InkWell(
                          onTap: () => onReplyTap(doc.id, username),
                          child: Text("Reply", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}