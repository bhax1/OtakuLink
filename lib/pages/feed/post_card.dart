import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/pages/feed/feed_services/user_cache.dart';
import 'package:otakulink/pages/feed/post_details.dart';
import 'package:otakulink/pages/feed/reaction_helper.dart';
import 'package:otakulink/pages/home/manga_details_page.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
import 'package:otakulink/theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isFriend;
  final String postId;
  final Function(int) onTabChange;

  const PostCard({
    super.key,
    required this.data,
    required this.isFriend,
    required this.postId,
    required this.onTabChange,
  });

  // --- REACTION LOGIC (Unchanged) ---
  Future<void> _handleReaction(String reactionType, String? currentReaction) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection('feeds').doc(postId);
    if (currentReaction == reactionType) {
      await docRef.update({'reactions.$uid': FieldValue.delete()});
    } else {
      await docRef.update({'reactions.$uid': reactionType});
    }
  }

  void _showReactionMenu(BuildContext context, String? currentReaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
        _handleReaction(type, null); // Pass null or current doesn't matter for menu selection
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          ReactionTypes.getEmoji(type),
          style: const TextStyle(fontSize: 28), // Large Emoji
        ),
      ),
    );
  }

  // --- NAVIGATION LOGIC ---
  void _handleProfileTap(BuildContext context, String targetUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == targetUserId) {
      onTabChange(4); 
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfilePage(userId: targetUserId)));
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final String type = data['type'] ?? 'normal';
    final String content = data['comment'] ?? '';
    final int replyCount = data['replyCount'] ?? 0;
    
    // Linked Manga Data
    final String? mangaId = data['mangaId']?.toString();
    final String? mangaTitle = data['mangaTitle'];
    final String? mangaImage = data['mangaImage'];

    final Map<String, dynamic> reactionsMap = data['reactions'] ?? {};
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String? myReaction = reactionsMap[currentUserId];

    String timeString = '';
    if (data['timestamp'] != null) {
      timeString = timeago.format((data['timestamp'] as Timestamp).toDate());
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: UserCache.streamUser(data['userId']),
      builder: (context, snapshot) {
        final user = snapshot.data ?? {};
        final username = user['username'] ?? 'User';
        final photoUrl = user['photoURL'] ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  children: [
                    InkWell(
                      onTap: () => _handleProfileTap(context, data['userId']),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                        child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderTitle(username, type, data),
                          Text(timeString, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // BODY CONTENT
                if (content.isNotEmpty) ...[
                  Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
                  const SizedBox(height: 12),
                ],

                // --- LINKED MANGA CARD (The Cool Part) ---
                if (mangaId != null && mangaImage != null)
                  _buildLinkedMangaCard(context, mangaId, mangaTitle ?? 'Unknown', mangaImage),

                const SizedBox(height: 12),

                // TYPE SPECIFIC CONTENT (Polls)
                if (type == 'poll')
                  PollWidget(postId: postId, data: data),

                const Divider(height: 24),
                
                // ACTIONS ROW
                Row(
                  children: [
                    // REACTION BUTTON
                    Expanded(
                      child: InkWell(
                        // Tap toggles "Like" specifically (default), Long press shows menu
                        onTap: () => _handleReaction(ReactionTypes.like, myReaction),
                        onLongPress: () => _showReactionMenu(context, myReaction),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon / Emoji Logic
                              myReaction != null 
                                ? Text(ReactionTypes.getEmoji(myReaction), style: const TextStyle(fontSize: 18))
                                : Icon(Icons.thumb_up_alt_outlined, color: Colors.grey[600], size: 20),
                              
                              const SizedBox(width: 6),
                              
                              // Text Label Logic
                              Text(
                                myReaction != null 
                                    ? ReactionTypes.getName(myReaction) 
                                    : "Like",
                                style: TextStyle(
                                  color: myReaction != null 
                                      ? ReactionTypes.getColor(myReaction) 
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              
                              // Count (optional, usually shown separately in FB, but inline here is fine)
                              if (reactionsMap.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                                  child: Text("${reactionsMap.length}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // REPLY BUTTON (Unchanged)
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsPage(postId: postId, postData: data, onTabChange: onTabChange))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mode_comment_outlined, color: Colors.grey[600], size: 20),
                              const SizedBox(width: 6),
                              Text(replyCount > 0 ? "$replyCount Replies" : "Reply", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- NEW: LINKED MANGA CARD WIDGET ---
  Widget _buildLinkedMangaCard(BuildContext context, String id, String title, String image) {
    return GestureDetector(
      onTap: () {
        // Navigate to the Manga Details page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailsPage(
              mangaId: int.parse(id),
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
          ),
        );
      },
      child: Container(
        height: 100, // Fixed height for consistency
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            // Cover Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: image,
                width: 70,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: Colors.grey[200]),
              ),
            ),
            
            // Info Column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.link, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        const Text("View Details", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            // Arrow Icon
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey[400]),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTitle(String username, String type, Map<String, dynamic> data) {
    if (type == 'activity') {
      final activity = data['activityType'] ?? 'is';
      return RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 15),
          children: [
            TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: " is $activity ", style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      );
    }
    // For Q&A, Polls, or Normal
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 15),
        children: [
          TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (type == 'qa')
            const TextSpan(text: " asked a question", style: TextStyle(color: Colors.grey)),
          if (type == 'poll')
            const TextSpan(text: " started a poll", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- POLL WIDGET (Previous logic, ensure it's imported or defined) ---
class PollWidget extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  const PollWidget({super.key, required this.postId, required this.data});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  @override
  Widget build(BuildContext context) {
    final List<dynamic> options = widget.data['pollOptions'] ?? [];
    final List<dynamic>? images = widget.data['pollImages']; 
    final Map<String, dynamic> votes = widget.data['pollVotes'] ?? {}; 
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final String pollType = widget.data['pollType'] ?? 'text';
    
    int totalVotes = votes.length;
    bool hasVoted = votes.containsKey(currentUid);
    int? myVoteIndex = hasVoted ? votes[currentUid] : null;
    
    List<int> counts = List.filled(options.length, 0);
    votes.forEach((uid, optionIndex) {
      if (optionIndex is int && optionIndex < counts.length) {
        counts[optionIndex]++;
      }
    });

    Future<void> handleVote(int index) async {
      final docRef = FirebaseFirestore.instance.collection('feeds').doc(widget.postId);
      if (hasVoted && myVoteIndex == index) {
        await docRef.update({'pollVotes.$currentUid': FieldValue.delete()});
      } else {
        await docRef.update({'pollVotes.$currentUid': index});
      }
    }

    // --- RENDER CHARACTER/IMAGE POLL ---
    if (pollType == 'image' && images != null) {
      // 1. Determine dynamic columns based on count
      final int columnCount = options.length > 4 ? 3 : 2;
      // 2. Adjust aspect ratio so 3-column cards aren't too tall/narrow for text
      final double aspectRatio = options.length > 4 ? 0.75 : 0.8;
      // 3. Adjust spacing slightly for denser grids
      final double spacing = options.length > 4 ? 8.0 : 10.0;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Use the dynamic values here
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio, 
        ),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final double percent = totalVotes == 0 ? 0 : (counts[index] / totalVotes);
          final bool isSelected = myVoteIndex == index;

          return GestureDetector(
            onTap: () => handleVote(index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    // Add placeholder to prevent ugly layout shift while loading
                    placeholder: (c, u) => Container(color: Colors.grey[200]),
                  ),
                ),
                if (hasVoted)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected 
                          ? AppColors.primary.withOpacity(0.4) 
                          : Colors.black.withOpacity(0.6), 
                    ),
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent]
                      )
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Important for tighter spacing
                      children: [
                        Text(
                          options[index],
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            // Slightly smaller font for 3-column layout
                            fontSize: columnCount == 3 ? 12 : 14
                          ),
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasVoted)
                          Text(
                            "${(percent * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isSelected)
                  Center(child: Icon(Icons.check_circle, color: Colors.white, size: columnCount == 3 ? 32 : 40)),
              ],
            ),
          );
        },
      );
    }

    // --- RENDER STANDARD TEXT POLL (Unchanged) ---
    return Column(
      children: List.generate(options.length, (index) {
        final double percent = totalVotes == 0 ? 0 : (counts[index] / totalVotes);
        final bool isSelected = myVoteIndex == index;

        return GestureDetector(
          onTap: () => handleVote(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
              color: Colors.grey[50],
            ),
            child: Stack(
              children: [
                if (hasVoted)
                  FractionallySizedBox(
                    widthFactor: percent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text(options[index], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      const Spacer(),
                      if (hasVoted)
                        Text("${(percent * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}