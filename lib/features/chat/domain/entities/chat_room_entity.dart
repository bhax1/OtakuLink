class ChatRoomEntity {
  final String id;
  final bool isGroup;
  final List<String> participants;

  // Group specific
  final String? groupName;
  final String? groupIconUrl;
  final String? adminId;

  // Metadata
  final Map<String, int> unreadCounts;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const ChatRoomEntity({
    required this.id,
    required this.isGroup,
    required this.participants,
    this.groupName,
    this.groupIconUrl,
    this.adminId,
    required this.unreadCounts,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageTimestamp,
    this.updatedAt,
    this.createdAt,
  });

  factory ChatRoomEntity.empty() {
    return const ChatRoomEntity(
      id: '',
      isGroup: false,
      participants: [],
      unreadCounts: {},
    );
  }

  ChatRoomEntity copyWith({
    String? id,
    bool? isGroup,
    List<String>? participants,
    String? groupName,
    String? groupIconUrl,
    String? adminId,
    Map<String, int>? unreadCounts,
    String? lastMessageText,
    String? lastMessageSenderId,
    DateTime? lastMessageTimestamp,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return ChatRoomEntity(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      participants: participants ?? this.participants,
      groupName: groupName ?? this.groupName,
      groupIconUrl: groupIconUrl ?? this.groupIconUrl,
      adminId: adminId ?? this.adminId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
