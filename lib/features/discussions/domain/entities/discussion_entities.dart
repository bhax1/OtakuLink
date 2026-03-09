class DiscussionComment {
  final String id;
  final int mangaId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String textContent;
  final String? replyToId;
  final Map<String, dynamic>? metadata;
  final String? chapterId;
  final String? chapterNumber;
  final DateTime createdAt;
  final List<DiscussionReaction> reactions;

  DiscussionComment({
    required this.id,
    required this.mangaId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.textContent,
    this.replyToId,
    this.metadata,
    this.chapterId,
    this.chapterNumber,
    required this.createdAt,
    this.reactions = const [],
  });

  DiscussionComment copyWith({List<DiscussionReaction>? reactions}) {
    return DiscussionComment(
      id: id,
      mangaId: mangaId,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      textContent: textContent,
      replyToId: replyToId,
      metadata: metadata,
      chapterId: chapterId,
      chapterNumber: chapterNumber,
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
    );
  }
}

class DiscussionReaction {
  final String discussionId;
  final String userId;
  final String emoji;

  DiscussionReaction({
    required this.discussionId,
    required this.userId,
    required this.emoji,
  });
}
