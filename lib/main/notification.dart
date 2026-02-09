import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/pages/comments/comments_page.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/follow_service.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/friend_service.dart';
import 'package:otakulink/theme.dart';
import 'package:otakulink/pages/profile/viewprofile.dart'; 

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  // ---------------------------------------------------------
  // 🔹 NEW: Mark All As Read
  // ---------------------------------------------------------
  Future<void> _markAllAsRead() async {
    if (_currentUserId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    
    // Get only unread notifications to save write costs
    final snapshots = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('notification')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications are already read.'))
      );
      return;
    }

    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All marked as read.'))
      );
    }
  }

  void _showNotificationOptions(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isRead = data['isRead'] ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 10),
              
              // Option 1: Toggle Read/Unread
              ListTile(
                leading: Icon(isRead ? Icons.mark_email_unread : Icons.mark_email_read, color: AppColors.primary),
                title: Text(isRead ? 'Mark as unread' : 'Mark as read'),
                onTap: () {
                  Navigator.pop(context); // Close menu
                  doc.reference.update({'isRead': !isRead});
                },
              ),
              
              // Option 2: Delete Individual Notification
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete this notification', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context); // Close menu
                  doc.reference.delete();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
  }

  // ---------------------------------------------------------
  // 🔹 NEW: Confirmation Dialog + Clear Logic
  // ---------------------------------------------------------
  Future<void> _showClearConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Notifications?'),
          content: const Text('This will permanently delete all your notifications. This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete All', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllNotifications(); // Call the actual delete function
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllNotifications() async {
    if (_currentUserId == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final snapshots = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('notification')
        .get();

    if (snapshots.docs.isEmpty) return;

    for (var doc in snapshots.docs) batch.delete(doc.reference);
    
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications cleared.')));
    }
  }

  // ---------------------------------------------------------
  // Existing Logic
  // ---------------------------------------------------------
  Future<void> _handleNotificationTap(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    
    // 1. Mark as read
    if (data['isRead'] == false) {
      doc.reference.update({'isRead': true});
    }

    final String type = data['type'] ?? '';

    // 2. Navigate based on Type
    if (type == 'reply' || type == 'mention' || type == 'reaction') {
       final int? mangaId = data['mangaId']; 
       final String? mangaName = data['mangaName']; 
       final String? commentId = data['commentId']; 
       
       if (mangaId != null && mangaName != null) {
         Navigator.push(context, MaterialPageRoute(
             builder: (_) => CommentsPage(
               mangaId: mangaId, 
               mangaName: mangaName, 
               userId: _currentUserId!, 
               jumpToCommentId: commentId
             )));
       }
    } 
    else if (type == 'follow' || type == 'friend_request' || type == 'friend_accept') {
       final String? senderId = data['senderId'];
       if (senderId != null) {
         Navigator.push(context, MaterialPageRoute(
             builder: (_) => ViewProfilePage(userId: senderId)));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
           if (_currentUserId != null) ...[
             IconButton(
               icon: const Icon(Icons.done_all), 
               tooltip: "Mark all as read",
               onPressed: _markAllAsRead
             ),
             IconButton(
               icon: const Icon(Icons.delete_sweep), 
               tooltip: "Clear all",
               onPressed: _showClearConfirmation
             ),
           ]
        ],
      ),
      body: _currentUserId == null 
        ? const Center(child: Text("Please login"))
        : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notification')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No notifications"));

          return ListView.separated(
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final bool isRead = data['isRead'] ?? false;
              final String photoUrl = data['senderPhoto'] ?? '';
              final String senderName = data['senderName'] ?? 'Someone';
              final String message = data['message'] ?? '';
              final Timestamp? ts = data['timestamp'];
              final String type = data['type'] ?? 'unknown';
              final String senderId = data['senderId'];
              final String? reactionEmoji = data['reactionEmoji'];
              final bool isFriendRequestHandled = type == 'friend_request' && (data['edited'] == true);

              // Icon Logic (Keep existing logic)
              IconData typeIcon = Icons.info;
              Color typeColor = Colors.grey;
              if (type == 'reply') { typeIcon = Icons.reply; typeColor = Colors.blue; }
              else if (type == 'mention') { typeIcon = Icons.alternate_email; typeColor = Colors.orange; }
              else if (type == 'reaction') { typeIcon = Icons.favorite; typeColor = Colors.pink; }
              else if (type == 'follow') { typeIcon = Icons.person_add; typeColor = Colors.blueAccent; }
              else if (type == 'friend_request') { typeIcon = Icons.people; typeColor = AppColors.primary; }
              else if (type == 'friend_accept') { typeIcon = Icons.check_circle; typeColor = Colors.green; }

              return Material(
                color: isRead ? Colors.white : AppColors.primary.withOpacity(0.05),
                child: InkWell(
                  // 🔹 TAP: Opens the notification (existing)
                  onTap: () => _handleNotificationTap(doc),
                  // 🔹 LONG PRESS: Shows options menu (NEW)
                  onLongPress: () => _showNotificationOptions(context, doc), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar (Same as before)
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfilePage(userId: senderId))),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey[200],
                                    child: ClipOval(
                                      child: (photoUrl.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: photoUrl,
                                              fit: BoxFit.cover,
                                              width: 48, height: 48,
                                              placeholder: (context, url) => Container(color: Colors.grey[300]),
                                              errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                                            )
                                          : const Icon(Icons.person, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: (type == 'reaction' && reactionEmoji != null && reactionEmoji.isNotEmpty)
                                        ? SizedBox(width: 16, height: 16, child: Center(child: Text(reactionEmoji, style: const TextStyle(fontSize: 12, height: 1))))
                                        : Icon(typeIcon, size: 14, color: typeColor),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(width: 12),
                            
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                                      children: [
                                        TextSpan(text: "$senderName ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: message),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ts != null ? _formatTimestamp(ts) : "Just now",
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (type == 'follow') _buildFollowButton(senderId),
                              
                            // Unread Dot
                            if (!isRead && type != 'follow') 
                               Container(margin: const EdgeInsets.only(left: 8, top: 8), width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                          ],
                        ),

                        if (type == 'friend_request' && !isFriendRequestHandled)
                          Padding(
                            padding: const EdgeInsets.only(left: 60, top: 8),
                            child: Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => FriendService.acceptFriendRequest(senderId, _currentUserId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary, 
                                    foregroundColor: Colors.white, 
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 16)
                                  ),
                                  child: const Text("Confirm"),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => FriendService.cancelRequest(senderId, _currentUserId, 'declined'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 16)
                                  ),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFollowButton(String targetUserId) {
    return StreamBuilder<String>(
      stream: FollowService.getFollowStatusStream(_currentUserId, targetUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final isFollowing = snapshot.data == 'following';

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: SizedBox(
            height: 32,
            child: isFollowing
                ? OutlinedButton(
                    onPressed: () => FollowService.unfollowUser(_currentUserId, targetUserId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: const Text("Following", style: TextStyle(fontSize: 12, color: Colors.black87)),
                  )
                : ElevatedButton(
                    onPressed: () => FollowService.followUser(_currentUserId, targetUserId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: const Text("Follow Back", style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.day}/${date.month}/${date.year}";
  }
}