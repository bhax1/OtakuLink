import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/theme.dart';

import 'comments_page_widgets/comment_tile.dart';
import 'comments_services/comments_service.dart';
import '../../services/notification_service.dart';

const int ITEMS_PER_PAGE = 20;

class CommentsPage extends StatefulWidget {
  final int mangaId;
  final String mangaName; 
  final String userId;
  final String? jumpToCommentId;

  const CommentsPage({
    Key? key,
    required this.mangaId,
    required this.mangaName,
    required this.userId,
    this.jumpToCommentId,
  }) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  // Service Instances
  final CommentsService _commentsService = CommentsService();
  final NotificationService _notificationService = NotificationService();

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  int _currentPage = 1;
  String? _highlightedCommentId; 
  bool _hasPerformedInitialJump = false; 

  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _replyingToUserId;
  String? _replyingToTextSnippet;

  List<QueryDocumentSnapshot> _allComments = [];

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  void _activateReplyMode(String commentId, String userName, String userId, String textContent) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _replyingToUserId = userId; 
      _replyingToTextSnippet = textContent;
      
      _commentController.text = "@$userName ";
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length)
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelReplyMode() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
      _replyingToUserId = null;
      _replyingToTextSnippet = null;
      _commentController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _insertSpoilerTag() {
    final text = _commentController.text;
    final selection = _commentController.selection;
    if (!selection.isValid) return;

    final selectedText = text.substring(selection.start, selection.end);
    final replacement = ">!$selectedText!<";
    final newText = text.replaceRange(selection.start, selection.end, replacement);
    
    setState(() {
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + replacement.length - (selectedText.isEmpty ? 2 : 0),
        ),
      );
    });
    _focusNode.requestFocus();
  }

  void _handleJumpToComment(String targetCommentId) {
    int index = _allComments.indexWhere((doc) => doc.id == targetCommentId);

    if (index != -1) {
      int targetPage = (index / ITEMS_PER_PAGE).floor() + 1;
      int indexOnPage = index % ITEMS_PER_PAGE;

      setState(() {
        _currentPage = targetPage;
        _highlightedCommentId = targetCommentId;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _scrollController.hasClients) {
            int itemsOnThisPage = (_currentPage * ITEMS_PER_PAGE > _allComments.length) 
                ? _allComments.length % ITEMS_PER_PAGE 
                : ITEMS_PER_PAGE;

            int visualIndex = (itemsOnThisPage - 1) - indexOnPage;
            
            final double estimatedOffset = visualIndex * 140.0; 
            final double maxScroll = _scrollController.position.maxScrollExtent;
            final double targetOffset = estimatedOffset > maxScroll ? maxScroll : estimatedOffset;

            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            );
          }
          
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _highlightedCommentId = null);
          });
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comment not found.")));
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String safeName = 'Anonymous';
      String? safePhoto = user.photoURL;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        safeName = userData['username'] ?? user.displayName ?? 'Anonymous'; 
        safePhoto = userData['photoURL'] ?? safePhoto;
      }

      // Prepare Context
      Map<String, dynamic>? replyContext;
      if (_replyingToCommentId != null) {
        replyContext = {
          'id': _replyingToCommentId,
          'username': _replyingToUserName,
          'text': _replyingToTextSnippet,
        };
      }

      // 1. Post to Firestore
      final docRef = await _commentsService.postComment(
        mangaId: widget.mangaId,
        userId: widget.userId,
        username: safeName,
        userPhoto: safePhoto,
        text: text,
        replyContext: replyContext,
      );

      // 2. Notify Reply Target
      if (_replyingToUserId != null) {
        await _notificationService.sendNotification(
          currentUserId: widget.userId,
          targetUserId: _replyingToUserId!,
          type: 'reply',
          senderName: safeName,
          senderPhoto: safePhoto,
          mangaId: widget.mangaId,
          mangaName: widget.mangaName,
          commentId: docRef.id,
          message: 'replied to your comment in ${widget.mangaName}',
        );
      }

      // 3. Process Mentions
      await _notificationService.processMentions(
        text: text,
        senderName: safeName,
        senderId: widget.userId,
        senderPhoto: safePhoto,
        mangaId: widget.mangaId,
        mangaName: widget.mangaName,
        commentId: docRef.id,
        replyToUserName: _replyingToUserName,
      );

      _cancelReplyMode();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleReactionNotification(String targetUserId, String commentId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    String senderName = userDoc.data()?['username'] ?? user.displayName ?? 'Anonymous';
    String? senderPhoto = userDoc.data()?['photoURL'] ?? user.photoURL;

    await _notificationService.sendNotification(
      currentUserId: widget.userId,
      targetUserId: targetUserId,
      type: 'reaction',
      senderName: senderName,
      senderPhoto: senderPhoto,
      mangaId: widget.mangaId,
      mangaName: widget.mangaName,
      commentId: commentId,
      message: 'reacted to your comment in ${widget.mangaName}',
      reactionEmoji: emoji,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Discussion Board'),
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: Colors.grey[200], height: 1),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _commentsService.getCommentsStream(widget.mangaId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error loading comments"));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  _allComments = snapshot.data!.docs;
                  
                  if (widget.jumpToCommentId != null && !_hasPerformedInitialJump && _allComments.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_hasPerformedInitialJump) {
                        _hasPerformedInitialJump = true;
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _handleJumpToComment(widget.jumpToCommentId!);
                        });
                      }
                    });
                  }

                  if (_allComments.isEmpty) return _buildEmptyState();

                  final totalItems = _allComments.length;
                  final totalPages = (totalItems / ITEMS_PER_PAGE).ceil();
                  
                  if (_currentPage > totalPages && totalPages > 0) _currentPage = totalPages;
                  if (_currentPage < 1) _currentPage = 1;

                  final int startIndex = (_currentPage - 1) * ITEMS_PER_PAGE;
                  final int endIndex = (startIndex + ITEMS_PER_PAGE < totalItems) ? startIndex + ITEMS_PER_PAGE : totalItems;

                  final pageComments = _allComments.sublist(startIndex, endIndex).reversed.toList();

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: pageComments.length,
                          itemBuilder: (context, index) {
                            final doc = pageComments[index];
                            final data = doc.data() as Map<String, dynamic>;
                            
                            return MangaPanelTile(
                              key: ValueKey(doc.id),
                              commentId: doc.id,
                              mangaId: widget.mangaId,
                              data: data,
                              currentUserId: widget.userId,
                              allCommentsSnapshot: _allComments,
                              onReply: _activateReplyMode,
                              onQuoteClick: _handleJumpToComment,
                              onReactionSent: _handleReactionNotification,
                              isHighlighted: doc.id == _highlightedCommentId,
                            );
                          },
                        ),
                      ),
                      if (totalPages > 1) _buildPaginationBar(totalPages),
                    ],
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(top: BorderSide(color: Colors.grey[200]!))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Colors.grey[600]),
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          ...List.generate(totalPages, (index) {
             int pageNum = index + 1;
             if (pageNum == 1 || pageNum == totalPages || (pageNum >= _currentPage - 1 && pageNum <= _currentPage + 1)) {
               return GestureDetector(
                 onTap: () => setState(() => _currentPage = pageNum),
                 child: Container(
                   margin: const EdgeInsets.symmetric(horizontal: 4),
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(
                     color: _currentPage == pageNum ? AppColors.primary : Colors.transparent,
                     borderRadius: BorderRadius.circular(4),
                   ),
                   child: Text("$pageNum", style: TextStyle(
                       color: _currentPage == pageNum ? Colors.white : Colors.grey[600], 
                       fontWeight: _currentPage == pageNum ? FontWeight.bold : FontWeight.normal
                   )),
                 ),
               );
             } else if ((pageNum == 2 && _currentPage > 4) || (pageNum == totalPages - 1 && _currentPage < totalPages - 3)) {
               return Text("...", style: TextStyle(color: Colors.grey[400]));
             }
             return const SizedBox.shrink();
          }),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Colors.grey[600]),
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No comments yet.", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_replyingToUserName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text("Replying to @$_replyingToUserName", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                    GestureDetector(onTap: _cancelReplyMode, child: const Icon(Icons.close, size: 18, color: Colors.grey))
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end, 
              children: [
                GestureDetector(
                  onTap: _insertSpoilerTag,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(right: 8, bottom: 4), 
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: Icon(Icons.visibility_off_outlined, color: Colors.grey[600], size: 20),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.black87),
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 5, 
                      textInputAction: TextInputAction.newline, 
                      decoration: InputDecoration(
                        hintText: "Enter thoughts (>!spoiler!<)...",
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSending ? null : _postComment,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 20,
                      child: _isSending 
                        ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}