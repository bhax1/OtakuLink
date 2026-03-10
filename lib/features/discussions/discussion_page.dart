import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/discussions/domain/entities/discussion_entities.dart';
import 'package:otakulink/features/discussions/presentation/controllers/discussion_controller.dart';
import 'discussion_page_widgets/discussion_tile.dart';
import 'package:go_router/go_router.dart';
import 'data/repositories/discussion_repository.dart';

class DiscussionPage extends ConsumerStatefulWidget {
  final int mangaId;
  final String mangaName;
  final String? chapterId;
  final String? highlightedCommentId;
  final String? mangaCover;
  final String? mangaDescription;

  const DiscussionPage({
    super.key,
    required this.mangaId,
    required this.mangaName,
    this.chapterId,
    this.highlightedCommentId,
    this.mangaCover,
    this.mangaDescription,
  });

  @override
  ConsumerState<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends ConsumerState<DiscussionPage> {
  static const int ITEMS_PER_PAGE = 20;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  DiscussionComment? _replyingTo;
  bool _hasScrolledToHighlight = false;
  String? _activeHighlightId;
  bool _hasPerformedInitialJump = false;

  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _activeHighlightId = widget.highlightedCommentId;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _handleJumpToComment(String targetCommentId) async {
    final repo = ref.read(discussionRepositoryProvider);
    int targetPage = await repo.getCommentPageNumber(
      mangaId: widget.mangaId,
      commentId: targetCommentId,
      chapterId: widget.chapterId,
      itemsPerPage: ITEMS_PER_PAGE,
    );

    if (mounted) {
      setState(() {
        _activeHighlightId = targetCommentId;
        _hasScrolledToHighlight = false; // Allow re-scroll
      });

      await ref
          .read(
            discussionControllerProvider((
              mangaId: widget.mangaId,
              chapterId: widget.chapterId,
            )).notifier,
          )
          .loadComments(page: targetPage);

      // Scroll after loading
      _scrollToHighlight(
        ref
            .read(
              discussionControllerProvider((
                mangaId: widget.mangaId,
                chapterId: widget.chapterId,
              )),
            )
            .comments,
      );
    }
  }

  void _insertSpoilerTag() {
    final text = _commentController.text;
    final selection = _commentController.selection;
    if (!selection.isValid) return;

    final selectedText = text.substring(selection.start, selection.end);
    final replacement = ">!$selectedText!<";
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );

    setState(() {
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset:
              selection.start +
              replacement.length -
              (selectedText.isEmpty ? 2 : 0),
        ),
      );
    });
    _focusNode.requestFocus();
  }

  void _scrollToHighlight(List<DiscussionComment> comments) {
    if (_activeHighlightId == null || _hasScrolledToHighlight) return;

    final index = comments.indexWhere((c) => c.id == _activeHighlightId);
    if (index != -1) {
      _hasScrolledToHighlight = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Delay to allow ListView to settle
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _scrollController.hasClients) {
            // Using logic from user snippet: (_currentPage > 1) ? 200.0 : 0.0 or calculated
            final double targetOffset = (index * 130.0).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );

            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            );

            _highlightTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _activeHighlightId = null);
            });
          }
        });
      });
    }
  }

  void _activateReplyMode(DiscussionComment comment) {
    setState(() {
      _replyingTo = comment;
      _commentController.text = "@${comment.username} ";
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelReplyMode() {
    setState(() {
      _replyingTo = null;
      _commentController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    Map<String, dynamic>? metadata;
    if (_replyingTo != null) {
      metadata = {
        'id': _replyingTo!.id,
        'userId': _replyingTo!.userId,
        'text': _replyingTo!.textContent,
      };
    }

    final success = await ref
        .read(
          discussionControllerProvider((
            mangaId: widget.mangaId,
            chapterId: widget.chapterId,
          )).notifier,
        )
        .postComment(
          text,
          replyToId: _replyingTo?.id,
          metadata: metadata,
          chapterNumber: widget.chapterId != null
              ? (widget.chapterId == 'oneshot'
                    ? 'Oneshot'
                    : (widget.chapterId?.split('-').last ?? ''))
              : null,
          mangaTitle: widget.mangaName,
          mangaCoverUrl: widget.mangaCover,
          mangaDescription: widget.mangaDescription,
        );

    if (success) {
      _cancelReplyMode();
      // Scroll to top of page 1
      await ref
          .read(
            discussionControllerProvider((
              mangaId: widget.mangaId,
              chapterId: widget.chapterId,
            )).notifier,
          )
          .loadComments(page: 1);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (mangaId: widget.mangaId, chapterId: widget.chapterId);
    final state = ref.watch(discussionControllerProvider(args));
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Handle initial jump logic from user snippet
    if (widget.highlightedCommentId != null &&
        !_hasPerformedInitialJump &&
        state.comments.isNotEmpty) {
      _hasPerformedInitialJump = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleJumpToComment(widget.highlightedCommentId!);
      });
    }

    // Listen for error messages
    ref.listen(
      discussionControllerProvider((
        mangaId: widget.mangaId,
        chapterId: widget.chapterId,
      )),
      (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
    );

    // Scroll if comments just loaded (non-initial jump)
    if (!state.isLoading &&
        state.comments.isNotEmpty &&
        _activeHighlightId != null &&
        !_hasScrolledToHighlight) {
      _scrollToHighlight(state.comments);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mangaName, style: const TextStyle(fontSize: 16)),
              Text(
                "${state.totalCount} Comments",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (state.isSending) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: state.isLoading && state.comments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(discussionControllerProvider(args).notifier)
                            .loadComments(page: 1);
                      },
                      child: state.comments.isEmpty
                          ? ListView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: _buildEmptyState(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: state.comments.length,
                                    itemBuilder: (context, index) {
                                      final comment = state.comments[index];
                                      return DiscussionTile(
                                        comment: comment,
                                        currentUserId: currentUserId,
                                        onReply: _activateReplyMode,
                                        onQuoteClick: _handleJumpToComment,
                                        isHighlighted:
                                            _activeHighlightId == comment.id,
                                      );
                                    },
                                  ),
                                ),
                                if (state.totalCount > ITEMS_PER_PAGE)
                                  _buildPaginationBar(
                                    (state.totalCount / ITEMS_PER_PAGE).ceil(),
                                  ),
                              ],
                            ),
                    ),
            ),
            if (currentUserId != null)
              _buildInputArea(theme, state)
            else
              _buildGuestPrompt(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    final theme = Theme.of(context);
    final currentArgs = (mangaId: widget.mangaId, chapterId: widget.chapterId);
    final currentPage = ref
        .watch(discussionControllerProvider(currentArgs))
        .currentPage;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 1
                    ? () => ref
                          .read(
                            discussionControllerProvider(currentArgs).notifier,
                          )
                          .loadComments(page: currentPage - 1)
                    : null,
              ),
              ...List.generate(totalPages, (index) {
                int pageNum = index + 1;
                bool isCurrent = currentPage == pageNum;
                // Simplified pagination window logic similar to user snippet
                if (pageNum == 1 ||
                    pageNum == totalPages ||
                    (pageNum >= currentPage - 1 &&
                        pageNum <= currentPage + 1)) {
                  return GestureDetector(
                    onTap: () => ref
                        .read(
                          discussionControllerProvider(currentArgs).notifier,
                        )
                        .loadComments(page: pageNum),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "$pageNum",
                        style: TextStyle(
                          color: isCurrent
                              ? theme.colorScheme.onPrimary
                              : theme.textTheme.bodyMedium?.color?.withOpacity(
                                  0.6,
                                ),
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                } else if ((pageNum == 2 && currentPage > 4) ||
                    (pageNum == totalPages - 1 &&
                        currentPage < totalPages - 3)) {
                  return const Text("...");
                }
                return const SizedBox.shrink();
              }),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages
                    ? () => ref
                          .read(
                            discussionControllerProvider(currentArgs).notifier,
                          )
                          .loadComments(page: currentPage + 1)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("No discussions yet. Be the first!"));
  }

  Widget _buildGuestPrompt(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.cardColor,
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 12),
            const Expanded(child: Text("Log in to join the discussion.")),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text("Log In"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, DiscussionState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_replyingTo != null) _buildReplyPreview(theme),
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
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.visibility_off_outlined,
                      color: theme.iconTheme.color?.withOpacity(0.7),
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    enabled: !state.isSending,
                    decoration: const InputDecoration(
                      hintText: "Comment (>!spoiler!<)...",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: state.isSending ? null : _postComment,
                  icon: state.isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      color: theme.colorScheme.primary.withOpacity(0.1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Replying to @${_replyingTo!.username}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: _cancelReplyMode,
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}

// Note: AppBar subtitle is not standard, I'll fix the UI in next step.
