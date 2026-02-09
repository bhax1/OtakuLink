import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/pages/feed/post_card.dart';
import 'package:otakulink/pages/home/manga_details_page.dart';
import 'package:otakulink/theme.dart';
import 'package:otakulink/pages/feed/feed_services/user_cache.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
import 'package:otakulink/pages/feed/reply_widget.dart';
import 'package:otakulink/pages/feed/reaction_helper.dart'; // Ensure this is imported
import 'package:timeago/timeago.dart' as timeago;

class PostDetailsPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData; // Initial data (optional usage now)
  final Function(int) onTabChange;

  const PostDetailsPage({
    super.key, 
    required this.postId, 
    required this.postData,
    required this.onTabChange
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _replyController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  
  String? _targetParentId;
  String? _targetUsername;

  @override
  void initState() {
    super.initState();
    _targetParentId = widget.postId;
  }

  // --- REACTION LOGIC FOR MAIN POST ---
  Future<void> _handleMainReaction(String type, String? current) async {
    final uid = currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('feeds').doc(widget.postId);

    if (current == type) {
      // Toggle off
      await ref.update({'reactions.$uid': FieldValue.delete()});
    } else {
      // Set new reaction
      await ref.update({'reactions.$uid': type});
    }
  }

  void _showMainReactionMenu(BuildContext context, String? current) {
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
        _handleMainReaction(type, null);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          ReactionTypes.getEmoji(type),
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  // --- REPLY LOGIC ---
  void _setReplyTarget(String id, String? username) {
    setState(() {
      _targetParentId = id;
      _targetUsername = username;
    });
  }

  void _cancelReplyTarget() {
    setState(() {
      _targetParentId = widget.postId;
      _targetUsername = null;
    });
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    _replyController.clear();
    final targetId = _targetParentId ?? widget.postId;
    
    // Reset target to main post after sending
    _cancelReplyTarget();

    await FirebaseFirestore.instance.collection('feeds').doc(widget.postId).collection('replies').add({
      'userId': currentUser!.uid,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'parentId': targetId,
    });

    await FirebaseFirestore.instance.collection('feeds').doc(widget.postId).update({'replyCount': FieldValue.increment(1)});
  }

  void _handleProfileTap(String targetUserId) {
    if (currentUser != null && currentUser!.uid == targetUserId) {
      Navigator.pop(context);
      widget.onTabChange(4); 
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfilePage(userId: targetUserId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Thread", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMainPost(),
                  const Divider(thickness: 1, height: 1),
                  _buildRepliesStream(),
                ],
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMainPost() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('feeds').doc(widget.postId).snapshots(),
      builder: (context, postSnapshot) {
        if (!postSnapshot.hasData) return const SizedBox();
        
        final data = postSnapshot.data!.data() as Map<String, dynamic>;
        
        // Data Extraction
        final String type = data['type'] ?? 'normal';
        final String content = data['comment'] ?? '';
        final String? mangaId = data['mangaId']?.toString();
        final String? mangaTitle = data['mangaTitle'];
        final String? mangaImage = data['mangaImage'];
        
        // Reaction Data
        final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
        final myId = currentUser!.uid;
        final myReaction = reactions[myId] as String?;

        return StreamBuilder<Map<String, dynamic>>(
          stream: UserCache.streamUser(data['userId']),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data ?? {};
            final username = user['username'] ?? 'User';
            final photoUrl = user['photoURL'] ?? '';

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER (Aligned with Feed) ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _handleProfileTap(data['userId']),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                          child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderTitle(username, type, data),
                            if (data['timestamp'] != null)
                              Text(
                                timeago.format((data['timestamp'] as Timestamp).toDate()),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // --- CONTENT TEXT ---
                  if (content.isNotEmpty) ...[
                    Text(content, style: const TextStyle(fontSize: 16, height: 1.4)),
                    const SizedBox(height: 12),
                  ],

                  // --- LINKED MANGA (Exact Match to Feed) ---
                  if (mangaId != null && mangaImage != null)
                     _buildLinkedMangaCard(mangaId, mangaTitle ?? 'Unknown', mangaImage),

                  const SizedBox(height: 12),

                  // --- POLL WIDGET (If type is poll) ---
                  if (type == 'poll')
                    PollWidget(postId: widget.postId, data: data),

                  const SizedBox(height: 16),

                  // --- ACTION BAR ---
                  Row(
                    children: [
                      // Reaction Button
                      GestureDetector(
                        onTap: () => _handleMainReaction(ReactionTypes.like, myReaction),
                        onLongPress: () => _showMainReactionMenu(context, myReaction),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: myReaction != null ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                myReaction != null ? ReactionTypes.getEmoji(myReaction) : ReactionTypes.getEmoji(ReactionTypes.like), // Default icon
                                style: TextStyle(fontSize: myReaction != null ? 18 : 16)
                              ),
                              const SizedBox(width: 6),
                              
                              if (myReaction == null && reactions.isEmpty)
                                Text("Like", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))
                              else
                                Text(
                                  myReaction != null ? ReactionTypes.getName(myReaction) : "${reactions.length}", 
                                  style: TextStyle(
                                    color: myReaction != null ? AppColors.primary : Colors.grey[700], 
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Reply Count Indicator
                      Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text("${data['replyCount'] ?? 0} Comments", style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPER: Header Title (Copied from PostCard) ---
  Widget _buildHeaderTitle(String username, String type, Map<String, dynamic> data) {
    if (type == 'activity') {
      final activity = data['activityType'] ?? 'is';
      return RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 16),
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
        style: const TextStyle(color: Colors.black, fontSize: 16),
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

  // --- HELPER: Linked Manga Card (Copied from PostCard) ---
  Widget _buildLinkedMangaCard(String id, String title, String image) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailsPage(
              mangaId: int.parse(id),
              userId: currentUser!.uid,
            ),
          ),
        );
      },
      child: Container(
        height: 100, // Matches Feed
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
                    const Row(
                      children: [
                        Icon(Icons.link, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text("View Details", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
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

  // ... (keep _buildRepliesStream and _buildInputArea the same) ...
  // Be sure to include the _buildRepliesStream and _buildInputArea methods from your previous code here.
  
  Widget _buildRepliesStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feeds')
          .doc(widget.postId)
          .collection('replies')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        
        final allDocs = snapshot.data!.docs;
        
        // Find top-level comments (direct replies to post)
        final topLevelComments = allDocs.where((doc) {
           final data = doc.data() as Map<String, dynamic>;
           return (data['parentId'] ?? widget.postId) == widget.postId;
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topLevelComments.length,
          itemBuilder: (context, index) {
            return CommentTree(
              doc: topLevelComments[index],
              allDocs: allDocs,
              postId: widget.postId,
              depth: 0,
              onReplyTap: _setReplyTarget,
              onTabChange: widget.onTabChange,
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_targetUsername != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text("Replying to $_targetUsername", style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  const Spacer(),
                  InkWell(onTap: _cancelReplyTarget, child: const Icon(Icons.close, size: 16))
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: "Write a reply...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(onPressed: _sendReply, icon: const Icon(Icons.send, color: Colors.white, size: 18)),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// --- NEW WIDGET: Recursive Comment Tree with Toggle ---
class CommentTree extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final List<QueryDocumentSnapshot> allDocs;
  final String postId;
  final int depth;
  final Function(String, String?) onReplyTap;
  final Function(int) onTabChange;

  const CommentTree({
    super.key,
    required this.doc,
    required this.allDocs,
    required this.postId,
    required this.depth,
    required this.onReplyTap,
    required this.onTabChange
  });

  @override
  State<CommentTree> createState() => _CommentTreeState();
}

class _CommentTreeState extends State<CommentTree> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Find children for this comment
    final children = widget.allDocs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['parentId'] == widget.doc.id;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The Comment itself
        ReplyWidget(
          doc: widget.doc, 
          postId: widget.postId, 
          depth: widget.depth, 
          onReplyTap: widget.onReplyTap,
          onTabChange: widget.onTabChange
        ),

        // The "View Replies" Toggle
        if (children.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 16.0 + (widget.depth * 8) + 40, bottom: 8), // Indent to align with text
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 20, height: 1, color: Colors.grey[300]), // Little line
                  const SizedBox(width: 8),
                  Text(
                    _isExpanded 
                        ? "Hide replies" 
                        : "View ${children.length} replies",
                    style: TextStyle(
                      color: Colors.grey[600], 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Recursive Children (Hidden by default)
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0), // Indent children
            child: Column(
              children: children.map((childDoc) {
                return CommentTree(
                  doc: childDoc,
                  allDocs: widget.allDocs,
                  postId: widget.postId,
                  depth: widget.depth + 1,
                  onReplyTap: widget.onReplyTap,
                  onTabChange: widget.onTabChange,
                );
              }).toList(),
            ),
          )
      ],
    );
  }
}