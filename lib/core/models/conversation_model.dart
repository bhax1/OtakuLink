import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final bool isGroup;
  final List<String> participants;

  final Map<String, dynamic>? groupMetadata;
  final Map<String, dynamic> lastMessage;
  final Map<String, dynamic> unreadCounts;
  final Timestamp? updatedAt;

  Conversation({
    required this.id,
    required this.isGroup,
    required this.participants,
    this.groupMetadata,
    required this.lastMessage,
    required this.unreadCounts,
    this.updatedAt,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      isGroup: data['isGroup'] ?? false,
      participants: List<String>.from(data['participants'] ?? []),
      groupMetadata: data['groupMetadata'],
      lastMessage: Map<String, dynamic>.from(data['lastMessage'] ?? {}),
      unreadCounts: Map<String, dynamic>.from(data['unreadCounts'] ?? {}),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}
