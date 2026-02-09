import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/theme.dart';

// Assuming these exist in your project structure
import 'widgets_message/message_bubble.dart'; 
// import 'widgets_message/message_options.dart'; // Replaced with internal logic

class MessengerPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendProfilePic;

  const MessengerPage({
    Key? key,
    required this.friendId,
    required this.friendName,
    this.friendProfilePic = "",
  }) : super(key: key);

  @override
  _MessengerPageState createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  late String _conversationId;
  
  // 🔹 Pagination: We track the limit locally. 
  // Increasing this limit updates the stream, keeping real-time sync for ALL loaded messages.
  int _currentLimit = 20;
  final int _limitIncrement = 20;
  StreamSubscription? _messageSubscription;

  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier(false);
  final ValueNotifier<List<DocumentSnapshot>> _messagesNotifier = ValueNotifier([]);
  
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConversationId();
    _setupMessageStream(); // Initial Load
    _scrollController.addListener(_scrollListener);
    _setCurrentlyViewing(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _isSendingNotifier.dispose();
    _messagesNotifier.dispose();
    _setCurrentlyViewing(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setCurrentlyViewing(true);
    } else if (state == AppLifecycleState.paused) {
      _setCurrentlyViewing(false);
    }
  }

  // --- 1. SETUP & STREAMS ---

  void _initializeConversationId() {
    final currentUser = _auth.currentUser!;
    final userId = currentUser.uid;
    _conversationId = userId.hashCode <= widget.friendId.hashCode
        ? 'conversation_${userId}_${widget.friendId}'
        : 'conversation_${widget.friendId}_${userId}';
  }

  // 🔹 Robust Stream Handling
  void _setupMessageStream() {
    _messageSubscription?.cancel(); // Cancel previous stream if increasing limit

    _messageSubscription = _firestore
        .collection('messages')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_currentLimit)
        .snapshots()
        .listen((snapshot) {
      _messagesNotifier.value = snapshot.docs;
      _isLoadingMore = false; // Reset loading state when data arrives
    });

    // Listen for read receipts/viewing status
    _firestore.collection('messages').doc(_conversationId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final viewing = data['currentlyViewing'] as Map<String, dynamic>? ?? {};
      if (viewing[widget.friendId] == true) {
        _resetFriendUnreadCount();
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50 &&
        !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() {
    // If we have fewer messages than the limit, we've reached the end.
    if (_messagesNotifier.value.length < _currentLimit) return;

    setState(() {
      _isLoadingMore = true;
      _currentLimit += _limitIncrement;
    });
    
    // Re-subscribe with the higher limit. 
    // This is safer than manual merging for chat apps to avoid "ghost" messages or sync issues.
    _setupMessageStream(); 
  }

  // --- 2. LOGIC: REACTIONS & UPDATES ---

  Future<void> _setCurrentlyViewing(bool isViewing) async {
    if (_auth.currentUser == null) return;
    await _firestore.collection('messages').doc(_conversationId).set({
      'currentlyViewing': { _auth.currentUser!.uid: isViewing }
    }, SetOptions(merge: true));
    if (isViewing) _resetUnreadCount();
  }

  Future<void> _resetUnreadCount() async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('messages').doc(_conversationId).update({
      'unreadCounts.$uid': 0
    }).catchError((e) => null);
  }

  Future<void> _resetFriendUnreadCount() async {
    await _firestore.collection('messages').doc(_conversationId).update({
      'unreadCounts.${widget.friendId}': 0
    }).catchError((e) => null);
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final uid = _auth.currentUser!.uid;
    final docRef = _firestore
        .collection('messages')
        .doc(_conversationId)
        .collection('messages')
        .doc(messageId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (reactions[uid] == emoji) {
        // Toggle OFF if clicking same emoji
        reactions.remove(uid);
      } else {
        // Update/Set new emoji
        reactions[uid] = emoji;
      }

      transaction.update(docRef, {'reactions': reactions});
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    await _firestore
        .collection('messages')
        .doc(_conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _editMessage(String messageId, String oldText) async {
    final TextEditingController editController = TextEditingController(text: oldText);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty && editController.text != oldText) {
                await _firestore
                    .collection('messages')
                    .doc(_conversationId)
                    .collection('messages')
                    .doc(messageId)
                    .update({
                      'messageText': editController.text.trim(),
                      'isEdited': true, // 🔹 Mark as edited
                    });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    editController.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _isSendingNotifier.value = true;

    final senderId = _auth.currentUser!.uid;
    final receiverId = widget.friendId;
    final ref = _firestore.collection('messages').doc(_conversationId);

    try {
      final docSnap = await ref.get();
      bool isFriendViewing = false;
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final viewing = data['currentlyViewing'] as Map<String, dynamic>? ?? {};
        isFriendViewing = viewing[receiverId] == true;
      }

      final batch = _firestore.batch();
      final msgRef = ref.collection('messages').doc();
      
      batch.set(msgRef, {
        'senderId': senderId,
        'messageText': text,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {}, // Initialize empty reactions
        'isEdited': false,
      });

      Map<String, dynamic> updateData = {
        'lastMessage': text,
        'timestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      };

      if (!isFriendViewing) {
        updateData['unreadCounts.$receiverId'] = FieldValue.increment(1);
      }

      batch.set(ref, updateData, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint("Send Error: $e");
    } finally {
      _isSendingNotifier.value = false;
    }
  }

  // --- 3. UI COMPONENTS ---

  // 🔹 The New Enhanced Options Menu (Replaces MessageOptions)
  void _showEnhancedOptions(BuildContext context, String messageId, String messageText, bool isMine) {
    // Standard Emoji Set
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reaction Row
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _toggleReaction(messageId, emojis[index]);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 15),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 30),
            // Actions
            if (isMine) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(messageId, messageText);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
            ],
            // "Copy" is available for everyone
            ListTile(
               leading: const Icon(Icons.copy),
               title: const Text('Copy Text'),
               onTap: () {
                 // Implement Clipboard copy here
                 Navigator.pop(context);
               },
            )
          ],
        ),
      ),
    );
  }

  // 🔹 Visual Helper: Date Header
  bool _shouldShowDateHeader(int index, List<DocumentSnapshot> messages) {
    if (index == messages.length - 1) return true;
    final currentMsgTime = (messages[index]['timestamp'] as Timestamp?)?.toDate();
    final nextMsgTime = (messages[index + 1]['timestamp'] as Timestamp?)?.toDate();
    if (currentMsgTime == null || nextMsgTime == null) return false;
    return !_isSameDay(currentMsgTime, nextMsgTime);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  Widget _buildDateHeader(Timestamp? timestamp) {
    if (timestamp == null) return const SizedBox.shrink();
    final date = timestamp.toDate();
    final now = DateTime.now();
    String text;
    if (_isSameDay(date, now)) text = "Today";
    else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) text = "Yesterday";
    else text = DateFormat('MMM d, yyyy').format(date);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser!.uid;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.friendProfilePic.isNotEmpty
                    ? CachedNetworkImageProvider(widget.friendProfilePic)
                    : null,
                backgroundColor: Colors.white24,
                child: widget.friendProfilePic.isEmpty
                    ? Text(widget.friendName.isNotEmpty ? widget.friendName[0] : '?', style: const TextStyle(color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.friendName, style: const TextStyle(fontSize: 18, overflow: TextOverflow.ellipsis))),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<List<DocumentSnapshot>>(
                valueListenable: _messagesNotifier,
                builder: (context, messages, _) {
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet. Say hi! 👋', style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the top (end of list in reverse)
                      if (index == messages.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator.adaptive()));
                      }

                      final message = messages[index];
                      final data = message.data() as Map<String, dynamic>;
                      final isMine = data['senderId'] == currentUserId;
                      
                      // 🔹 Extract Reactions
                      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
                      final hasReactions = reactions.isNotEmpty;
                      
                      // Visual Grouping
                      bool isNextMessageFromSameSender = false;
                      if (index > 0) {
                        final nextData = messages[index - 1].data() as Map<String, dynamic>;
                        isNextMessageFromSameSender = nextData['senderId'] == data['senderId'];
                      }

                      final showDate = _shouldShowDateHeader(index, messages);

                      return Column(
                        children: [
                          if (showDate) _buildDateHeader(data['timestamp']),
                          
                          GestureDetector(
                            onLongPress: () {
                              _showEnhancedOptions(
                                context, 
                                message.id, 
                                data['messageText'] ?? '', 
                                isMine
                              );
                            },
                            child: Padding(
                              // Add padding to accommodate the overlapping reaction pill
                              padding: EdgeInsets.only(bottom: hasReactions ? 20.0 : (!isNextMessageFromSameSender ? 8.0 : 2.0)),
                              child: Stack(
                                clipBehavior: Clip.none, // Allow reaction to overflow
                                children: [
                                  // The Message Bubble
                                  MessageBubble(
                                    message: data['messageText'] ?? '',
                                    isMine: isMine,
                                    friendName: widget.friendName,
                                    friendProfilePic: widget.friendProfilePic,
                                    showAvatar: !isMine && (!isNextMessageFromSameSender),
                                  ),

                                  // 🔹 "Edited" Label
                                  if (data['isEdited'] == true)
                                    Positioned(
                                      bottom: 4,
                                      right: isMine ? 12 : null,
                                      left: isMine ? null : 12, // Adjust based on your bubble padding
                                      child: const Text('edited', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                                    ),

                                  // 🔹 The Reaction Pill Overlay
                                  if (hasReactions)
                                    Positioned(
                                      bottom: -12, // Hang off the bottom
                                      right: isMine ? 10 : null,
                                      left: !isMine ? 50 : null, // 50 offset to clear avatar
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                                          ],
                                          border: Border.all(color: Colors.grey[200]!)
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Show up to 3 unique reaction emojis
                                            ...reactions.values.toSet().take(3).map((e) => Text(e, style: const TextStyle(fontSize: 12))),
                                            if (reactions.length > 1) 
                                              Text(" ${reactions.length}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            
            // Input Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 5)]
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isSendingNotifier,
                      builder: (context, isSending, _) {
                        return CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 22,
                          child: IconButton(
                            icon: isSending
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: isSending ? null : _sendMessage,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}