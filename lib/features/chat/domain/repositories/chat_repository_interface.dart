import 'package:otakulink/features/chat/domain/entities/chat_room_entity.dart';
import 'package:otakulink/features/chat/domain/entities/message_entity.dart';

abstract class ChatRepositoryInterface {
  Stream<List<ChatRoomEntity>> getConversationsStream();
  Stream<List<MessageEntity>> getMessagesStream(
    String conversationId,
    int limit,
  );

  Future<void> ensureConversationExists({required String friendId});

  Future<String> createGroupChat({
    required String groupName,
    required List<String> selectedUserIds,
    String? groupIconUrl,
  });

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? replyToId,
  });

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newText,
  );
  Future<void> deleteMessage(String conversationId, String messageId);
  Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String emoji,
  );
  Future<void> setViewingStatus(String conversationId, bool isViewing);

  // Group Management
  Future<void> addMembersToGroup({
    required String roomId,
    required List<String> userIds,
  });

  Future<void> updateGroupInfo({
    required String roomId,
    String? name,
    String? iconUrl,
  });

  Future<List<String>> getGroupMemberIds(String roomId);

  Future<void> removeMemberFromGroup({
    required String roomId,
    required String userId,
  });

  Future<void> leaveGroup(String roomId);

  Future<String?> getRoomAdminId(String roomId);

  Future<void> transferAdminRights({
    required String roomId,
    required String newAdminId,
  });

  Future<void> deleteGroup(String roomId);
}
