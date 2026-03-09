import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/chat/domain/entities/chat_room_entity.dart';
import 'package:otakulink/features/chat/domain/entities/message_entity.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/features/chat/domain/repositories/chat_repository_interface.dart';

class ChatRepositoryImpl implements ChatRepositoryInterface {
  final SupabaseClient _client;

  ChatRepositoryImpl({required SupabaseClient client}) : _client = client;

  String get _currentUid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception("Unauthorized to access ChatRepository.");
    return uid;
  }

  @override
  Stream<List<ChatRoomEntity>> getConversationsStream() {
    if (_client.auth.currentUser == null) return const Stream.empty();
    final String currentId = _currentUid;

    // View: Get all chat_rooms where user is in chat_room_participants
    // Supabase standard stream queries won't perfectly join without a defined view,
    // but we can query `chat_rooms` and filter on client, OR query `chat_room_participants`
    // and map to rooms. Given the schema, querying chat_room_participants is more direct.

    // For full reactivity with participants and rooms, extending via Postgres functions
    // or listening to both tables on the client is sometimes needed.
    // For simplicity with standard RLS views:

    return _client
        .from('chat_room_participants')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('user_id', currentId)
        .asyncMap((participantDocs) async {
          final roomIds = participantDocs
              .map((doc) => doc['room_id'] as String)
              .toList();
          if (roomIds.isEmpty) return [];

          // Fetch actual room data
          final roomResponse = await _client
              .from('chat_rooms')
              .select('''
            id,
            is_group,
            group_name,
            group_icon_url,
            admin_id,
            last_message_text,
            last_message_sender_id,
            last_message_timestamp,
            updated_at,
            created_at,
            chat_room_participants(user_id, unread_count)
          ''')
              .inFilter('id', roomIds)
              .order('updated_at', ascending: false);

          return roomResponse.map((room) {
            final participantsRaw =
                room['chat_room_participants'] as List<dynamic>? ?? [];
            List<String> participantIds = [];
            Map<String, int> unreads = {};

            for (var p in participantsRaw) {
              final uid = p['user_id'] as String;
              participantIds.add(uid);
              unreads[uid] = p['unread_count'] as int? ?? 0;
            }

            return ChatRoomEntity(
              id: room['id'] as String,
              isGroup: room['is_group'] ?? false,
              participants: participantIds,
              groupName: room['group_name'],
              groupIconUrl: room['group_icon_url'],
              adminId: room['admin_id'],
              unreadCounts: unreads,
              lastMessageText: room['last_message_text'],
              lastMessageSenderId: room['last_message_sender_id'],
              lastMessageTimestamp: room['last_message_timestamp'] != null
                  ? DateTime.parse(room['last_message_timestamp'])
                  : null,
              updatedAt: room['updated_at'] != null
                  ? DateTime.parse(room['updated_at'])
                  : null,
              createdAt: room['created_at'] != null
                  ? DateTime.parse(room['created_at'])
                  : null,
            );
          }).toList();
        });
  }

  @override
  Stream<List<MessageEntity>> getMessagesStream(
    String conversationId,
    int limit,
  ) {
    if (_client.auth.currentUser == null) return const Stream.empty();

    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit)
        .asyncMap((messageDocs) async {
          try {
            final msgIds = messageDocs.map((m) => m['id'] as String).toList();
            final replyToIds = messageDocs
                .map((m) => m['reply_to_id'] as String?)
                .whereType<String>()
                .toSet()
                .toList();

            Map<String, Map<String, String>> reactionMaps = {};
            Map<String, Map<String, dynamic>> replyMessages = {};
            Map<String, Map<String, dynamic>> senderProfiles = {};

            if (msgIds.isNotEmpty) {
              final reactionsRes = await _client
                  .from('chat_message_reactions')
                  .select('message_id, user_id, emoji')
                  .inFilter('message_id', msgIds);

              for (var r in reactionsRes) {
                final mId = r['message_id'] as String;
                final uId = r['user_id'] as String;
                final emote = r['emoji'] as String;
                reactionMaps.putIfAbsent(mId, () => {});
                reactionMaps[mId]![uId] = emote;
              }

              // Fetch main sender profiles
              final senderIds = messageDocs
                  .map((m) => m['sender_id'] as String?)
                  .whereType<String>()
                  .toSet()
                  .toList();

              if (senderIds.isNotEmpty) {
                final profilesRes = await _client
                    .from('profiles')
                    .select('id, display_name, avatar_url')
                    .inFilter('id', senderIds);
                for (var p in profilesRes) {
                  senderProfiles[p['id'] as String] = p;
                }
              }
            }

            if (replyToIds.isNotEmpty) {
              final replyRes = await _client
                  .from('chat_messages')
                  .select(
                    'id, message_text, sender_id, profiles!chat_messages_sender_id_fkey(display_name)',
                  )
                  .inFilter('id', replyToIds);

              for (var r in replyRes) {
                replyMessages[r['id'] as String] = r;
              }
            }

            return messageDocs.map((doc) {
              final mId = doc['id'] as String;
              final rxMap = reactionMaps[mId] ?? {};
              final rId = doc['reply_to_id'] as String?;
              final rData = rId != null ? replyMessages[rId] : null;
              final sId = (doc['sender_id'] as String?) ?? '';
              final sData = senderProfiles[sId];

              String? replySender;
              final profilesData = rData?['profiles'];
              if (profilesData is Map) {
                replySender = profilesData['display_name'] as String?;
              } else if (profilesData is List && profilesData.isNotEmpty) {
                replySender = profilesData[0]['display_name'] as String?;
              }

              return MessageEntity(
                id: mId,
                roomId: (doc['room_id'] as String?) ?? '',
                senderId: sId,
                messageText: (doc['message_text'] as String?) ?? '',
                isEdited: doc['is_edited'] ?? false,
                timestamp: doc['created_at'] != null
                    ? DateTime.tryParse(doc['created_at'].toString())
                    : null,
                reactions: rxMap,
                reactionCount: rxMap.length,
                replyToId: rId,
                replyToText:
                    (rData?['message_text'] as String?) ??
                    (rId != null ? "Message deleted" : null),
                replyToSenderName: replySender,
                senderName: sData?['display_name'] as String?,
                senderProfilePic: sData?['avatar_url'] as String?,
              );
            }).toList();
          } catch (e, stack) {
            SecureLogger.logError(
              "ChatRepository getMessagesStream asyncMap",
              e,
              stack,
            );
            return [];
          }
        });
  }

  @override
  Future<void> ensureConversationExists({required String friendId}) async {
    final myId = _currentUid;

    // Check if 1-on-1 room already exists
    // A 1-1 room is identified by is_group=false and exactly both participants
    final res = await _client.rpc(
      'get_direct_chat_room',
      params: {'p1': myId, 'p2': friendId},
    );

    if (res != null) {
      // Room exists
      return;
    }

    // Room doesn't exist, create it manually via multiple inserts
    final roomInsert = await _client
        .from('chat_rooms')
        .insert({
          'is_group': false,
          'admin_id': myId,
          'last_message_text': '',
          'last_message_sender_id': myId,
        })
        .select('id')
        .single();

    final roomId = roomInsert['id'] as String;

    await _client.from('chat_room_participants').insert([
      {'room_id': roomId, 'user_id': myId, 'unread_count': 0},
      {'room_id': roomId, 'user_id': friendId, 'unread_count': 0},
    ]);
  }

  @override
  Future<String> createGroupChat({
    required String groupName,
    required List<String> selectedUserIds,
    String? groupIconUrl,
  }) async {
    final myId = _currentUid;

    final roomInsert = await _client
        .from('chat_rooms')
        .insert({
          'is_group': true,
          'group_name': groupName,
          'group_icon_url': groupIconUrl,
          'admin_id': myId,
          'last_message_text': 'Group chat created',
          'last_message_sender_id': myId,
        })
        .select('id')
        .single();

    final roomId = roomInsert['id'] as String;

    final allUsers = {myId, ...selectedUserIds}.toList();
    final participantInserts = allUsers
        .map((uid) => {'room_id': roomId, 'user_id': uid, 'unread_count': 0})
        .toList();

    await _client.from('chat_room_participants').insert(participantInserts);
    SecureLogger.info('Group chat created: $roomId');

    return roomId;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? replyToId,
  }) async {
    final myId = _currentUid;
    if (text.trim().isEmpty) return;

    final insertData = {
      'room_id': conversationId,
      'sender_id': myId,
      'message_text': text.trim(),
    };
    if (replyToId != null) {
      insertData['reply_to_id'] = replyToId;
    }

    // Send the message natively
    await _client.from('chat_messages').insert(insertData);

    // Call RPC to increment unread count for non-viewing participants
    // We'll write the RPC next inside the sql schema, or we can fetch & update
    await _client.rpc(
      'increment_unread_counts',
      params: {'c_room_id': conversationId, 'c_sender_id': myId},
    );
  }

  @override
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newText,
  ) async {
    if (newText.trim().isEmpty) return;
    await _client
        .from('chat_messages')
        .update({
          'message_text': newText.trim(),
          'is_edited': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', _currentUid);
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _client
        .from('chat_messages')
        .delete()
        .eq('id', messageId)
        .eq('sender_id', _currentUid);
  }

  @override
  Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final myId = _currentUid;

    final existing = await _client
        .from('chat_message_reactions')
        .select()
        .eq('message_id', messageId)
        .eq('user_id', myId)
        .maybeSingle();

    if (existing != null) {
      if (existing['emoji'] == emoji) {
        // remove reaction
        await _client
            .from('chat_message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', myId);
      } else {
        // swap emoji
        await _client
            .from('chat_message_reactions')
            .update({
              'emoji': emoji,
              'created_at': DateTime.now().toIso8601String(),
            })
            .eq('message_id', messageId)
            .eq('user_id', myId);
      }
    } else {
      // add reaction
      await _client.from('chat_message_reactions').insert({
        'message_id': messageId,
        'user_id': myId,
        'emoji': emoji,
      });
    }
  }

  @override
  Future<void> setViewingStatus(String conversationId, bool isViewing) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    Map<String, dynamic> updateData = {'currently_viewing': isViewing};
    if (isViewing) {
      updateData['unread_count'] = 0;
    }

    try {
      await _client
          .from('chat_room_participants')
          .update(updateData)
          .eq('room_id', conversationId)
          .eq('user_id', myId);
    } catch (e, stack) {
      SecureLogger.logError("ChatRepository setViewingStatus", e, stack);
      // Might not be a participant yet if UI navigates super fast
    }
  }

  @override
  Future<void> addMembersToGroup({
    required String roomId,
    required List<String> userIds,
  }) async {
    final participants = userIds
        .map((uid) => {'room_id': roomId, 'user_id': uid, 'unread_count': 0})
        .toList();

    await _client.from('chat_room_participants').insert(participants);
  }

  @override
  Future<void> updateGroupInfo({
    required String roomId,
    String? name,
    String? iconUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['group_name'] = name;
    if (iconUrl != null) updates['group_icon_url'] = iconUrl;
    updates['updated_at'] = DateTime.now().toIso8601String();

    if (updates.isEmpty) return;

    await _client.from('chat_rooms').update(updates).eq('id', roomId);
  }

  @override
  Future<List<String>> getGroupMemberIds(String roomId) async {
    final res = await _client
        .from('chat_room_participants')
        .select('user_id')
        .eq('room_id', roomId);

    return (res as List).map((row) => row['user_id'] as String).toList();
  }

  @override
  Future<void> removeMemberFromGroup({
    required String roomId,
    required String userId,
  }) async {
    await _client
        .from('chat_room_participants')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  @override
  Future<void> leaveGroup(String roomId) async {
    final myId = _currentUid;
    await _client
        .from('chat_room_participants')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', myId);
    SecureLogger.info('User $myId left group: $roomId');
  }

  @override
  Future<String?> getRoomAdminId(String roomId) async {
    final res = await _client
        .from('chat_rooms')
        .select('admin_id')
        .eq('id', roomId)
        .single();
    return res['admin_id'] as String?;
  }

  @override
  Future<void> transferAdminRights({
    required String roomId,
    required String newAdminId,
  }) async {
    await _client
        .from('chat_rooms')
        .update({'admin_id': newAdminId})
        .eq('id', roomId);
    SecureLogger.info('Admin rights transferred for $roomId to: $newAdminId');
  }

  @override
  Future<void> deleteGroup(String roomId) async {
    // Cascading deletes on room_id in chat_messages and chat_room_participants
    // should handle the cleanup if the DB is set up with ON DELETE CASCADE.
    await _client.from('chat_rooms').delete().eq('id', roomId);
    SecureLogger.info('Group deleted: $roomId');
  }
}
