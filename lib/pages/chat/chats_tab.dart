import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml
import 'package:otakulink/pages/chat/chat_services/user_service.dart';
import 'package:otakulink/pages/chat/message.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> with AutomaticKeepAliveClientMixin {
  String searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  // 🔹 Helper: Format Timestamp (e.g., "10:30 AM", "Mon", "Feb 14")
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      return DateFormat('h:mm a').format(date);
    } else if (diff.inDays < 7) {
      return DateFormat('E').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  // 🔹 OPTIMIZED: Parallel data fetching
  Stream<List<Map<String, dynamic>>> _getConversationsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      
      // 1. Filter locally (Better: Use 'participants' array in Firestore to query directly)
      final relevantDocs = snapshot.docs.where((doc) {
        return doc.id.contains(currentUser.uid);
      }).toList();

      List<Map<String, dynamic>> results = [];

      // 2. Fetch User Data in Parallel (Fixes N+1 problem)
      await Future.wait(relevantDocs.map((doc) async {
        final parts = doc.id.split('_');
        if (parts.length < 3) return;

        // Find the other user's ID
        final otherUserId = parts.firstWhere(
          (id) => id != currentUser.uid && id != 'conversation', 
          orElse: () => ''
        );
        
        if (otherUserId.isEmpty) return;

        // Fetch using Cache Service
        final userData = await UserService().getUserData(otherUserId);
        if (userData == null) return;

        final unreadCounts = doc['unreadCounts'] as Map<String, dynamic>? ?? {};
        final myUnreadCount = unreadCounts[currentUser.uid] ?? 0;

        results.add({
          'friendDocId': otherUserId,
          'username': userData['username'],
          'photoURL': userData['photoURL'],
          'lastMessage': doc['lastMessage'] ?? '',
          'lastSenderId': doc['lastSenderId'] ?? '',
          'timestamp': doc['timestamp'],
          'unreadCount': myUnreadCount,
        });
      }));

      // 3. Sort again (Futures might finish out of order)
      results.sort((a, b) {
        Timestamp t1 = a['timestamp'] ?? Timestamp.now();
        Timestamp t2 = b['timestamp'] ?? Timestamp.now();
        return t2.compareTo(t1);
      });

      return results;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),

        // Chat List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getConversationsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No conversations yet"));
              }

              final chats = snapshot.data!;
              
              // Apply Search Filter locally
              final filteredChats = chats.where((chat) {
                final name = (chat['username'] ?? '').toString().toLowerCase();
                final msg = (chat['lastMessage'] ?? '').toString().toLowerCase();
                final query = searchQuery.toLowerCase();
                return query.isEmpty || name.contains(query) || msg.contains(query);
              }).toList();

              if (filteredChats.isEmpty) return const Center(child: Text("No matching chats"));

              return RefreshIndicator(
                onRefresh: () async => UserService().clearCache(),
                child: ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final isMe = chat['lastSenderId'] == currentUser?.uid;
                    final isUnread = chat['unreadCount'] > 0;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: (chat['photoURL'] != null && chat['photoURL'] != "")
                            ? CachedNetworkImageProvider(chat['photoURL'])
                            : const AssetImage('assets/pic/default_avatar.png') as ImageProvider,
                      ),
                      title: Text(
                        chat['username'] ?? 'Unknown',
                        style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600),
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMe ? "You: ${chat['lastMessage']}" : chat['lastMessage'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnread ? Colors.black87 : Colors.grey,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(chat['timestamp']),
                            style: TextStyle(fontSize: 12, color: isUnread ? Colors.blue : Colors.grey),
                          ),
                        ],
                      ),
                      // Unread Badge
                      trailing: isUnread
                          ? Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.blue, // Use primaryColor
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat['unreadCount'].toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessengerPage(
                              friendId: chat['friendDocId'],
                              friendName: chat['username'],
                              friendProfilePic: chat['photoURL'] ?? '',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}