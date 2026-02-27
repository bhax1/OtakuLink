import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/services/discussion_service.dart';
import 'package:otakulink/services/notification_service.dart';
import 'package:otakulink/services/user_service.dart';

import 'discussion_page_widgets/discussion_tile.dart';

const int ITEMS_PER_PAGE = 20;

// Changed to ConsumerStatefulWidget
class DiscussionPage extends ConsumerStatefulWidget {
  final int mangaId;
  final String mangaName;
  final String userId;
  final String? jumpToCommentId;

  const DiscussionPage({
    Key? key,
    required this.mangaId,
    required this.mangaName,
    required this.userId,
    this.jumpToCommentId,
  }) : super(key: key);

  @override
  ConsumerState<DiscussionPage> createState() => _DiscussionPageState();
}

// Changed to ConsumerState
class _DiscussionPageState extends ConsumerState<DiscussionPage> {
  final DiscussionService _commentsService = DiscussionService();
  final NotificationService _notificationService = NotificationService();

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late Stream<QuerySnapshot> _commentsStream;

  bool _isSending = false;
  int _currentPage = 1;
  String? _highlightedCommentId;
  bool _hasPerformedInitialJump = false;

  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _replyingToUserId;
  String? _replyingToTextSnippet;

  int _totalCommentCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeDiscussion();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeDiscussion() async {
    _updatePageStream();

    int count = await _commentsService.getTotalCommentsCount(widget.mangaId);
    if (mounted) {
      setState(() {
        _totalCommentCount = count;
      });
    }
  }

  void _updatePageStream() {
    setState(() {
      _commentsStream = _commentsService.getPaginatedCommentsStream(
        mangaId: widget.mangaId,
        limit: ITEMS_PER_PAGE,
        page: _currentPage,
      );
    });
  }

  void _activateReplyMode(
      String commentId, String userName, String userId, String textContent) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _replyingToUserId = userId;
      _replyingToTextSnippet = textContent;

      _commentController.text = "@$userName ";
      _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _commentController.text.length));
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
    final newText =
        text.replaceRange(selection.start, selection.end, replacement);

    setState(() {
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start +
              replacement.length -
              (selectedText.isEmpty ? 2 : 0),
        ),
      );
    });
    _focusNode.requestFocus();
  }

  void _handleJumpToComment(String targetCommentId) async {
    int targetPage = await _commentsService.getCommentPageNumber(
      mangaId: widget.mangaId,
      commentId: targetCommentId,
      itemsPerPage: ITEMS_PER_PAGE,
    );

    if (mounted) {
      setState(() {
        _currentPage = targetPage;
        _highlightedCommentId = targetCommentId;
      });
      _updatePageStream();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _scrollController.hasClients) {
            final double targetOffset = (_currentPage > 1) ? 200.0 : 0.0;
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            );

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _highlightedCommentId = null);
            });
          }
        });
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      // Accessing UserService via Riverpod
      final userService = ref.read(userServiceProvider);
      final currentUserId = userService.currentUserId;
      if (currentUserId == null) return;

      Map<String, dynamic>? replyContext;
      if (_replyingToCommentId != null) {
        replyContext = {
          'id': _replyingToCommentId,
          'userId': _replyingToUserId,
          'text': _replyingToTextSnippet,
        };
      }

      final docRef = await _commentsService.postComment(
        mangaId: widget.mangaId,
        userId: currentUserId,
        text: text,
        replyContext: replyContext,
      );

      Future(() async {
        final currentUserProfile =
            await userService.getUserProfile(currentUserId);
        final currentUserName = currentUserProfile?.username ?? 'Anonymous';

        if (_replyingToUserId != null) {
          await _notificationService.sendNotification(
            currentUserId: currentUserId,
            targetUserId: _replyingToUserId!,
            type: 'reply',
            mangaId: widget.mangaId,
            mangaName: widget.mangaName,
            commentId: docRef.id,
            message: 'replied to your comment in ${widget.mangaName}',
          );
        }

        await _notificationService.processMentions(
          text: text,
          senderId: currentUserId,
          currentUserName: currentUserName,
          mangaId: widget.mangaId,
          mangaName: widget.mangaName,
          commentId: docRef.id,
          replyToUserName: _replyingToUserName,
        );
      }).catchError((e) {
        debugPrint("Background notification error: $e");
      });

      _cancelReplyMode();
      _totalCommentCount++;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleReactionNotification(
      String targetUserId, String commentId, String emoji) async {
    // Accessing UserService via Riverpod
    final currentUserId = ref.read(userServiceProvider).currentUserId;
    if (currentUserId == null) return;

    await _notificationService.sendNotification(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
      type: 'reaction',
      mangaId: widget.mangaId,
      mangaName: widget.mangaName,
      commentId: commentId,
      message: 'reacted to your comment in ${widget.mangaName}',
      reactionEmoji: emoji,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Discussion Board'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
                color: theme.dividerColor.withOpacity(0.1), height: 1),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _commentsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error loading comments"));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allFetchedDocs = snapshot.data!.docs;

                  if (widget.jumpToCommentId != null &&
                      !_hasPerformedInitialJump &&
                      allFetchedDocs.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_hasPerformedInitialJump) {
                        _hasPerformedInitialJump = true;
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _handleJumpToComment(widget.jumpToCommentId!);
                        });
                      }
                    });
                  }

                  if (allFetchedDocs.isEmpty) return _buildEmptyState();

                  final totalPages =
                      (_totalCommentCount / ITEMS_PER_PAGE).ceil();
                  if (_currentPage > totalPages && totalPages > 0) {
                    _currentPage = totalPages;
                  }
                  if (_currentPage < 1) _currentPage = 1;

                  final int startIndex = (_currentPage - 1) * ITEMS_PER_PAGE;
                  final int endIndex =
                      (startIndex + ITEMS_PER_PAGE < allFetchedDocs.length)
                          ? startIndex + ITEMS_PER_PAGE
                          : allFetchedDocs.length;

                  if (startIndex >= allFetchedDocs.length)
                    return _buildEmptyState();

                  final pageComments = allFetchedDocs
                      .sublist(startIndex, endIndex)
                      .reversed
                      .toList();

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

                            return DiscussionTile(
                              key: ValueKey(doc.id),
                              commentId: doc.id,
                              mangaId: widget.mangaId,
                              data: data,
                              currentUserId: widget.userId,
                              allCommentsSnapshot: allFetchedDocs,
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
    // ... [Logic remains identical]
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
              top: BorderSide(color: theme.dividerColor.withOpacity(0.1)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: theme.iconTheme.color),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _updatePageStream();
                  }
                : null,
          ),
          ...List.generate(totalPages, (index) {
            int pageNum = index + 1;
            bool isCurrent = _currentPage == pageNum;
            if (pageNum == 1 ||
                pageNum == totalPages ||
                (pageNum >= _currentPage - 1 && pageNum <= _currentPage + 1)) {
              return GestureDetector(
                onTap: () {
                  setState(() => _currentPage = pageNum);
                  _updatePageStream();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text("$pageNum",
                      style: TextStyle(
                          color: isCurrent
                              ? theme.colorScheme.onPrimary
                              : theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.6),
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            } else if ((pageNum == 2 && _currentPage > 4) ||
                (pageNum == totalPages - 1 && _currentPage < totalPages - 3)) {
              return Text("...", style: TextStyle(color: Colors.grey[400]));
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Colors.grey[600]),
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                    _updatePageStream();
                  }
                : null,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_replyingToUserName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  border: Border(
                      left: BorderSide(
                          color: theme.colorScheme.primary, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text("Replying to @$_replyingToUserName",
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold))),
                    GestureDetector(
                        onTap: _cancelReplyMode,
                        child:
                            Icon(Icons.close, size: 18, color: theme.hintColor))
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
                    decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.05),
                        shape: BoxShape.circle),
                    child: Icon(Icons.visibility_off_outlined,
                        color: theme.iconTheme.color?.withOpacity(0.7),
                        size: 20),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: "Enter thoughts (>!spoiler!<)...",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSending ? null : _postComment,
                  child: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    radius: 20,
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
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
