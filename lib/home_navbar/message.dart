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

class _MessengerPageState extends State<MessengerPage> {
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

  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels == 0 &&
        _hasMoreMessages &&
        !_isLoadingNotifier.value) {
      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() async {
    if (_messagesNotifier.value.isEmpty) return;
    _isLoadingNotifier.value = true;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: MediaQuery.of(context).size.width / 2 - 20,
        top: MediaQuery.of(context).size.height / 2 - 20,
        child: Material(
          color: Colors.transparent,
          child: CircularProgressIndicator(color: accentColor),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    try {
      final lastMessage = _messagesNotifier.value.first;

      final olderMessages = await _firestore
          .collection('messages')
          .doc(_conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(lastMessage)
          .limit(20)
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
        SnackBar(content: Text("Error loading messages")),
      );
    } finally {
      _isLoadingNotifier.value = false;
      overlayEntry.remove();
    }
  }

  void _initializeConversation() {
    final currentUser = _auth.currentUser!;
    final userId = currentUser.uid;

    _conversationId = userId.hashCode <= widget.friendId.hashCode
        ? 'conversation_${userId}_${widget.friendId}'
        : 'conversation_${widget.friendId}_${userId}';

    _isLoadingNotifier.value = true;

    _firestore
        .collection('messages')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      _messagesNotifier.value = snapshot.docs.reversed.toList();
      _isLoadingNotifier.value = false;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    _isSendingNotifier.value = true;

    final messageText = _messageController.text.trim();
    final senderId = _auth.currentUser!.uid;

    try {
      await _firestore.collection('messages').doc(_conversationId).set({
        'lastMessage': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });

      _messageController.clear();

      // Send the new message to the messages collection
      final newMessage = await _firestore
          .collection('messages')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'messageText': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final newMessageSnapshot = await newMessage.get();
      _messagesNotifier.value.add(newMessageSnapshot);
    } catch (error) {
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      _isSendingNotifier.value = false;
    }
  }

  void _showMessageOptions(
      String messageId, String messageText, String senderId) {
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
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
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
        body: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<List<DocumentSnapshot>>(
                valueListenable: _messagesNotifier,
                builder: (context, messages, child) {
                  if (messages.isEmpty) {
                    return const Center(
                        child: Text('No messages yet. Start chatting!'));
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is UserScrollNotification) {
                        return true;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
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
                    ),
                  );
                },
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isSendingNotifier,
              builder: (context, isSending, child) {
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
                              borderSide:
                                  BorderSide(color: primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: isSending
                            ? const CircularProgressIndicator(
                                color: Colors.amber)
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
      ),
    );
  }
}
