import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/main.dart';

import '../widgets_message/message_bubble.dart';
import '../widgets_message/message_options.dart';

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

  late String _conversationId;
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<DocumentSnapshot>> _messagesNotifier =
      ValueNotifier<List<DocumentSnapshot>>([]);
  bool _hasMoreMessages = true;
  bool _showNewMessageButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConversation();
    _scrollController.addListener(_scrollListener);

    _setCurrentlyViewing(true); // mark as viewing when entering chat
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageController.dispose();
    _setCurrentlyViewing(false); // mark as not viewing when leaving chat
    super.dispose();
  }

  // 🔹 Handle app lifecycle (alt-tab, home button, resume, etc.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setCurrentlyViewing(true);
    } else {
      _setCurrentlyViewing(false);
    }
  }

  // 🔹 Mark user as currently viewing or not
  Future<void> _setCurrentlyViewing(bool isViewing) async {
    final currentUserId = _auth.currentUser!.uid;
    final conversationDoc = _firestore.collection('messages').doc(_conversationId);

    await conversationDoc.set({
      'currentlyViewing': {
        currentUserId: isViewing,
        '${currentUserId}_lastSeen': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isNearBottom()) _scrollToBottom();
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels == 0 &&
        _hasMoreMessages &&
        !_isLoadingNotifier.value) {
      _loadMoreMessages();
    }

    if (_isNearBottom() && _showNewMessageButton) {
      setState(() => _showNewMessageButton = false);
    }
  }

  void _loadMoreMessages() async {
    if (_messagesNotifier.value.isEmpty) return;
    _isLoadingNotifier.value = true;

    try {
      final lastMessage = _messagesNotifier.value.first;

      final olderMessages = await _firestore
          .collection('messages')
          .doc(_conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(lastMessage)
          .limit(10)
          .get();

      if (olderMessages.docs.isEmpty) {
        _hasMoreMessages = false;
      } else {
        _messagesNotifier.value = [
          ...olderMessages.docs.reversed,
          ..._messagesNotifier.value
        ];
      }
    } catch (e) {
      print("Error loading more messages: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error loading messages")),
      );
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _initializeConversation() {
    final currentUser = _auth.currentUser!;
    final userId = currentUser.uid;

    _conversationId = userId.hashCode <= widget.friendId.hashCode
        ? 'conversation_${userId}_${widget.friendId}'
        : 'conversation_${widget.friendId}_${userId}';

    _isLoadingNotifier.value = true;

    // 🔹 Listen for new messages
    _firestore
        .collection('messages')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      final newMessages = snapshot.docs.reversed.toList();

      if (_messagesNotifier.value.isEmpty) {
        _messagesNotifier.value = newMessages;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        final currentIds = _messagesNotifier.value.map((m) => m.id).toSet();
        final freshOnes =
            newMessages.where((m) => !currentIds.contains(m.id)).toList();

        if (freshOnes.isNotEmpty) {
          _messagesNotifier.value = [..._messagesNotifier.value, ...freshOnes];
          if (_isNearBottom()) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          } else {
            setState(() => _showNewMessageButton = true);
          }
        }
      }

      _isLoadingNotifier.value = false;
    });

    // 🔹 Reset your unread when opening chat
    _resetUnreadCount();

    // 🔹 Listen for friend viewing state → reset their unread
    _firestore.collection('messages').doc(_conversationId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final currentlyViewing = Map<String, dynamic>.from(data['currentlyViewing'] ?? {});
      
      if (currentlyViewing[widget.friendId] == true) {
        _resetFriendUnreadCount();
      }
    });
  }

  void _resetUnreadCount() async {
    final currentUserId = _auth.currentUser!.uid;
    final conversationDoc =
        _firestore.collection('messages').doc(_conversationId);

    try {
      await conversationDoc.update({'unreadCounts.$currentUserId': 0});
    } catch (e) {
      print("Error resetting unread count: $e");
    }
  }

  void _resetFriendUnreadCount() async {
    final conversationDoc = _firestore.collection('messages').doc(_conversationId);

    try {
      await conversationDoc.update({'unreadCounts.${widget.friendId}': 0});
    } catch (e) {
      print("Error resetting friend unread count: $e");
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return (maxScroll - currentScroll) < 200;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    _isSendingNotifier.value = true;

    final messageText = _messageController.text.trim();
    final senderId = _auth.currentUser!.uid;
    final receiverId = widget.friendId;

    try {
      final conversationRef = _firestore.collection('messages').doc(_conversationId);

      final conversationDoc = await conversationRef.get();
      final conversationData = conversationDoc.data() ?? {};

      final unreadCounts = Map<String, dynamic>.from(conversationData['unreadCounts'] ?? {});
      final currentlyViewing = Map<String, dynamic>.from(conversationData['currentlyViewing'] ?? {});

      // ✅ Only increment unread if receiver is not viewing
      if (currentlyViewing[receiverId] != true) {
        unreadCounts[receiverId] = (unreadCounts[receiverId] ?? 0) + 1;
      }

      await conversationRef.set({
        'lastMessage': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'unreadCounts': unreadCounts,
      }, SetOptions(merge: true));

      await conversationRef.collection('messages').add({
        'senderId': senderId,
        'messageText': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollToBottom();
      });
      _isSendingNotifier.value = false;
      _messageController.clear();
    }
  }

  void _showMessageOptions(String messageId, String messageText, String senderId) {
    MessageOptions.showMessageOptions(
      context,
      _conversationId,
      messageId,
      messageText,
      senderId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser!.uid;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
          title: Row(
            children: [
              CircleAvatar(
                backgroundImage: widget.friendProfilePic.isNotEmpty
                    ? CachedNetworkImageProvider(widget.friendProfilePic)
                    : null,
                child: widget.friendProfilePic.isEmpty
                    ? Text(
                        widget.friendName.isNotEmpty
                            ? widget.friendName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                      )
                    : null,
                backgroundColor: widget.friendProfilePic.isEmpty
                    ? Colors.blueGrey
                    : Colors.transparent,
              ),
              const SizedBox(width: 10),
              Text(widget.friendName),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<List<DocumentSnapshot>>(
                    valueListenable: _messagesNotifier,
                    builder: (context, messages, _) {
                      if (messages.isEmpty) {
                        return const Center(
                            child: Text('No messages yet. Start chatting!'));
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: _isLoadingNotifier,
                        builder: (context, isLoading, _) {
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: messages.length + (isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (isLoading && index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.amber),
                                  ),
                                );
                              }

                              final message = isLoading
                                  ? messages[index - 1]
                                  : messages[index];

                              final isMine = message['senderId'] == currentUserId;
                              return GestureDetector(
                                onLongPress: () => _showMessageOptions(
                                  message.id,
                                  message['messageText'],
                                  message['senderId'],
                                ),
                                child: MessageBubble(
                                  message: message['messageText'],
                                  isMine: isMine,
                                  friendName: widget.friendName,
                                  friendProfilePic: widget.friendProfilePic,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isSendingNotifier,
                  builder: (context, isSending, _) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              cursorColor: accentColor,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: isSending
                                ? const CircularProgressIndicator(color: Colors.amber)
                                : const Icon(Icons.send, color: Colors.amber),
                            onPressed: isSending ? null : _sendMessage,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_showNewMessageButton)
              Positioned(
                bottom: 70,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: primaryColor,
                  mini: true,
                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                  onPressed: () {
                    _scrollToBottom();
                    setState(() => _showNewMessageButton = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}