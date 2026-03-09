class MessageEntity {
  final String id;
  final String roomId;
  final String senderId;
  final String messageText;
  final DateTime? timestamp;
  final Map<String, String> reactions; // Using user_id as key, emoji as value
  final int reactionCount;
  final bool isEdited;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? senderName;
  final String? senderProfilePic;

  const MessageEntity({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.messageText,
    this.timestamp,
    required this.reactions,
    required this.reactionCount,
    required this.isEdited,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.senderName,
    this.senderProfilePic,
  });

  factory MessageEntity.empty() {
    return const MessageEntity(
      id: '',
      roomId: '',
      senderId: '',
      messageText: '',
      reactions: {},
      reactionCount: 0,
      isEdited: false,
    );
  }

  MessageEntity copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? messageText,
    DateTime? timestamp,
    Map<String, String>? reactions,
    int? reactionCount,
    bool? isEdited,
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
    String? senderName,
    String? senderProfilePic,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      messageText: messageText ?? this.messageText,
      timestamp: timestamp ?? this.timestamp,
      reactions: reactions ?? this.reactions,
      reactionCount: reactionCount ?? this.reactionCount,
      isEdited: isEdited ?? this.isEdited,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      senderName: senderName ?? this.senderName,
      senderProfilePic: senderProfilePic ?? this.senderProfilePic,
    );
  }
}
