import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  final String chatId;
  final bool isGroup;
  final String title;
  final String? photoUrl;
  final String lastMessage;
  final String lastSenderId;
  final Timestamp? timestamp;
  final int unreadCount;
  final List<String> participants;

  ChatConversation({
    required this.chatId,
    required this.isGroup,
    required this.title,
    this.photoUrl,
    required this.lastMessage,
    required this.lastSenderId,
    this.timestamp,
    required this.unreadCount,
    required this.participants,
  });
}
