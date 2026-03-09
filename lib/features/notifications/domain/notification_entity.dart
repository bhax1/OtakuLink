class NotificationEntity {
  final String id;
  final String userId;
  final String type; // 'reply', 'new_chapter', 'reaction', 'mention'
  final int? mangaId;
  final String? chapterId;
  final String? chapterNumber;
  final String? discussionId;
  final String? reactionEmoji;
  final String? actorId;
  final bool isRead;
  final DateTime createdAt;

  // Joined fields from Supabase
  final String? mangaTitle;
  final String? actorName;
  final String? actorAvatar;
  final String? discussionContent;

  NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    this.mangaId,
    this.chapterId,
    this.chapterNumber,
    this.discussionId,
    this.reactionEmoji,
    this.actorId,
    required this.isRead,
    required this.createdAt,
    this.mangaTitle,
    this.actorName,
    this.actorAvatar,
    this.discussionContent,
  });

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    // Handling joins from Supabase
    final mangaData = json['mangas'] as Map<String, dynamic>?;
    final actorData = json['profiles'] as Map<String, dynamic>?;
    final discussionData = json['discussions'] as Map<String, dynamic>?;

    return NotificationEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      mangaId: json['manga_id'] as int?,
      chapterId: json['chapter_id'] as String?,
      chapterNumber: json['chapter_number'] as String?,
      discussionId: json['discussion_id'] as String?,
      reactionEmoji: json['reaction_emoji'] as String?,
      actorId: json['actor_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      mangaTitle: mangaData?['title'] as String?,
      actorName: actorData?['username'] as String?,
      actorAvatar: actorData?['avatar_url'] as String?,
      discussionContent: discussionData?['text_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'manga_id': mangaId,
    'chapter_id': chapterId,
    'chapter_number': chapterNumber,
    'discussion_id': discussionId,
    'reaction_emoji': reactionEmoji,
    'actor_id': actorId,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };
}
