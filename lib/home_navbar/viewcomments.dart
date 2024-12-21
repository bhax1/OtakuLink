import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/main.dart';

class CommentsPage extends StatefulWidget {
  final int mangaId;
  final String userId;

  const CommentsPage({Key? key, required this.mangaId, required this.userId})
      : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String username = '';
  String photoURL = '';
  bool _hasMoreComments = true;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<DocumentSnapshot>> _commentsNotifier =
      ValueNotifier<List<DocumentSnapshot>>([]);

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _initializeConversation();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMoreComments &&
        !_isLoadingNotifier.value) {
      _loadMoreComments();
    }
  }

  void _loadMoreComments() async {
    if (_isLoadingNotifier.value || _commentsNotifier.value.isEmpty) return;

    _isLoadingNotifier.value = true;

    try {
      final lastMessage = _commentsNotifier.value.last;

      final olderMessages = await _firestore
          .collection('manga_comments')
          .doc(widget.mangaId.toString())
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(lastMessage)
          .limit(10)
          .get();

      if (olderMessages.docs.isEmpty) {
        _hasMoreComments = false;
      } else {
        _commentsNotifier.value = [
          ..._commentsNotifier.value,
          ...olderMessages.docs,
        ];
      }
    } catch (e) {
      print("Error loading more comments: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading more comments")),
      );
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  Future<void> _loadUserPreferences() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final fetchedUsername = userDoc.get('username') ?? 'User Name';
      final fetchedPhotoURL = userDoc.get('photoURL') ?? null;
      setState(() {
        username = fetchedUsername;
        photoURL = fetchedPhotoURL;
      });
    } catch (e) {
      debugPrint('Error fetching username from Firestore: $e');
    }
  }

  void _initializeConversation() {
    _isLoadingNotifier.value = true;

    _firestore
        .collection('manga_comments')
        .doc(widget.mangaId.toString())
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      _commentsNotifier.value = snapshot.docs.toList();
      _isLoadingNotifier.value = false;
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    _isSendingNotifier.value = true;

    final commentText = _commentController.text.trim();
    _commentController.clear();
    try {
      await _firestore
          .collection('manga_comments')
          .doc(widget.mangaId.toString())
          .collection('comments')
          .add({
        'user': widget.userId,
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showErrorDialog('Failed to post comment. Please try again.');
    } finally {
      _isSendingNotifier.value = false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comments'),
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
        ),
        body: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<List<DocumentSnapshot>>(
                valueListenable: _commentsNotifier,
                builder: (context, comments, child) {
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text('No comments yet. Be the first to comment!'),
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is UserScrollNotification) {
                        return true;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: comments.length,
                      controller: _scrollController,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final userRef =
                            _firestore.collection('users').doc(comment['user']);

                        return FutureBuilder<DocumentSnapshot>(
                          future: userRef.get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == null) {
                              return const ListTile(
                                leading: CircleAvatar(child: Icon(Icons.error)),
                                title: Text('User not found'),
                                subtitle: Text(''),
                              );
                            }

                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            final username = userData['username'] ?? 'Unknown';
                            final photoURL = userData['photoURL'] ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: photoURL.isNotEmpty
                                    ? CachedNetworkImageProvider(photoURL)
                                    : null,
                                child: photoURL.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Tooltip(
                                message: username,
                                child: Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      comment['text'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment['timestamp'] != null
                                        ? DateFormat('MMM dd, yyyy hh:mm a')
                                            .format((comment['timestamp']
                                                    as Timestamp)
                                                .toDate())
                                        : 'No Date',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
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
            ValueListenableBuilder<bool>(
              valueListenable: _isSendingNotifier,
              builder: (context, isSending, child) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
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
                        onPressed: isSending ? null : _addComment,
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
