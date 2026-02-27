import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/repository/chat_repository.dart';
import 'widgets_message/message_bubble.dart';
import 'widgets_message/message_options_modal.dart';

class MessengerPage extends ConsumerStatefulWidget {
  final String chatId;
  final String title;
  final String? profilePic;
  final bool isGroup;

  const MessengerPage({
    Key? key,
    required this.chatId,
    required this.title,
    this.profilePic,
    this.isGroup = false,
  }) : super(key: key);

  @override
  ConsumerState<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends ConsumerState<MessengerPage>
    with WidgetsBindingObserver {
  late ChatRepository _chatRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _conversationId;
  int _currentLimit = 20;
  final int _limitIncrement = 20;
  bool _isLoadingMore = false;

  StreamSubscription? _messageSubscription;
  final ValueNotifier<List<DocumentSnapshot>> _messagesNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatRepo = ref.read(chatRepositoryProvider);
    _conversationId = widget.chatId;

    _setupMessageStream();
    _scrollController.addListener(_scrollListener);
    _chatRepo.setViewingStatus(_conversationId, true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatRepo.setViewingStatus(_conversationId, false);
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _messagesNotifier.dispose();
    _isSendingNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatRepo.setViewingStatus(_conversationId, true);
    } else if (state == AppLifecycleState.paused) {
      _chatRepo.setViewingStatus(_conversationId, false);
    }
  }

  void _setupMessageStream() {
    _messageSubscription?.cancel();
    _messageSubscription = _chatRepo
        .getMessagesStream(_conversationId, _currentLimit)
        .listen((snapshot) {
      _messagesNotifier.value = snapshot.docs;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      if (_messagesNotifier.value.length >= _currentLimit) {
        setState(() {
          _isLoadingMore = true;
          _currentLimit += _limitIncrement;
        });
        _setupMessageStream();
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    _messageController.clear();
    _isSendingNotifier.value = true;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }

    await _chatRepo.sendMessage(conversationId: _conversationId, text: text);
    _isSendingNotifier.value = false;
  }

  void _showOptions(String messageId, String text, bool isMine) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MessageOptionsModal(
        isMine: isMine,
        messageText: text,
        onReaction: (emoji) =>
            _chatRepo.toggleReaction(_conversationId, messageId, emoji),
        onDelete: () => _chatRepo.deleteMessage(_conversationId, messageId),
        onEdit: () => _showEditDialog(messageId, text),
      ),
    );
  }

  Future<void> _showEditDialog(String messageId, String oldText) async {
    final controller = TextEditingController(text: oldText);
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
        ),
        title: const Text("Edit Message",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty &&
                  controller.text != oldText) {
                _chatRepo.editMessage(
                    _conversationId, messageId, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: _buildAppBar(theme),
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputArea(theme),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image:
                  (widget.profilePic != null && widget.profilePic!.isNotEmpty)
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(widget.profilePic!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: (widget.profilePic == null || widget.profilePic!.isEmpty)
                ? Center(
                    child: Text(widget.title.isNotEmpty ? widget.title[0] : '?',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold)),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final currentUid = _auth.currentUser!.uid;

    return ValueListenableBuilder<List<DocumentSnapshot>>(
      valueListenable: _messagesNotifier,
      builder: (context, messages, _) {
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'End of Chapter.\nStart writing...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, height: 1.5),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: messages.length + (_isLoadingMore ? 1 : 0),
          cacheExtent: 1000,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }

            final message = messages[index];
            final data = message.data() as Map<String, dynamic>;
            final isMine = data['senderId'] == currentUid;

            bool isNextFromSame = false;
            if (index > 0) {
              final nextData =
                  messages[index - 1].data() as Map<String, dynamic>;
              isNextFromSame = nextData['senderId'] == data['senderId'];
            }

            final showDate = _shouldShowDateHeader(index, messages);
            final reactions =
                Map<String, dynamic>.from(data['reactions'] ?? {});
            final hasReactions = reactions.isNotEmpty;
            final isEdited = data['isEdited'] == true;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate) _DateHeader(timestamp: data['timestamp']),
                RepaintBoundary(
                  child: GestureDetector(
                    onLongPress: () => _showOptions(
                        message.id, data['messageText'] ?? '', isMine),
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: hasReactions
                              ? 24.0
                              : (!isNextFromSame ? 16.0 : 4.0)),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MessageBubble(
                            message: data['messageText'] ?? '',
                            isMine: isMine,
                            friendName: widget.title,
                            friendProfilePic: widget.profilePic ?? '',
                            showAvatar: !isMine && !isNextFromSame,
                          ),
                          if (isEdited)
                            Positioned(
                              bottom: -16,
                              right: isMine ? 0 : null,
                              left: isMine ? null : (isNextFromSame ? 0 : 44),
                              child: Text('Edited',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).hintColor)),
                            ),
                          if (hasReactions)
                            _ReactionPill(
                              reactions: reactions,
                              isMine: isMine,
                              hasAvatarOffset: !isMine && !isNextFromSame,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          16, 12, 16, 16), // Extra bottom padding for safe area
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<bool>(
              valueListenable: _isSendingNotifier,
              builder: (context, isSending, _) {
                return InkWell(
                  onTap: isSending ? null : _handleSendMessage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48, // Match approximate height of 1-line text field
                    width: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.send_rounded,
                              color: theme.colorScheme.onPrimary, size: 22),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowDateHeader(int index, List<DocumentSnapshot> messages) {
    if (index == messages.length - 1) return true;
    final curr = (messages[index]['timestamp'] as Timestamp?)?.toDate();
    final next = (messages[index + 1]['timestamp'] as Timestamp?)?.toDate();
    if (curr == null || next == null) return false;
    return curr.year != next.year ||
        curr.month != next.month ||
        curr.day != next.day;
  }
}

class _DateHeader extends StatelessWidget {
  final Timestamp? timestamp;
  const _DateHeader({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final date = timestamp!.toDate();
    final now = DateTime.now();

    String text;
    final diff = now.difference(date).inDays;

    if (diff == 0 && now.day == date.day) {
      text = "Today";
    } else if (diff <= 1 && now.day - date.day == 1) {
      text = "Yesterday";
    } else {
      text = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.2))),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  final Map<String, dynamic> reactions;
  final bool isMine;
  final bool hasAvatarOffset;

  const _ReactionPill({
    required this.reactions,
    required this.isMine,
    required this.hasAvatarOffset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: -14,
      right: isMine ? 8 : null,
      left: !isMine ? (hasAvatarOffset ? 48 : 8) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(1, 1),
              blurRadius: 0, // Hard shadow for comic feel
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...reactions.values
                .toSet()
                .take(3)
                .map((e) => Text(e, style: const TextStyle(fontSize: 12))),
            if (reactions.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  "${reactions.length}",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
