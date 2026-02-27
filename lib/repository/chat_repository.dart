import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/models/conversation_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

// NEW: Stream provider for seamless Riverpod integration
final conversationsStreamProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).getConversationsStream();
});

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  Stream<List<Conversation>> getConversationsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromFirestore(doc))
            .toList());
  }

  Stream<QuerySnapshot> getMessagesStream(String conversationId, int limit) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<void> ensureConversationExists({required String friendId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final myId = currentUser.uid;
    final docId = myId.compareTo(friendId) <= 0
        ? 'conversation_${myId}_$friendId'
        : 'conversation_${friendId}_$myId';

    final ref = _firestore.collection('conversations').doc(docId);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'isGroup': false,
        'participants': [myId, friendId],
        'unreadCounts': {myId: 0, friendId: 0},
        'lastMessage': {'text': '', 'senderId': '', 'timestamp': null},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> createGroupChat({
    required String groupName,
    required List<String> selectedUserIds,
    String? groupIconUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Unauthorized");

    final myId = currentUser.uid;
    final allParticipants = {myId, ...selectedUserIds}.toList();

    final docRef = _firestore.collection('conversations').doc();

    await docRef.set({
      'isGroup': true,
      'participants': allParticipants,
      'groupMetadata': {
        'name': groupName,
        'iconUrl': groupIconUrl ?? '',
        'adminId': myId,
      },
      'unreadCounts': {for (var uid in allParticipants) uid: 0},
      'lastMessage': {
        'text': 'Group chat created',
        'senderId': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null || text.trim().isEmpty) return;

    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversationRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      List<String> participants = List<String>.from(data['participants'] ?? []);
      final viewingMap =
          Map<String, dynamic>.from(data['currentlyViewing'] ?? {});

      final messageRef = conversationRef.collection('messages').doc();
      transaction.set(messageRef, {
        'senderId': senderId,
        'messageText': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
        'reactionCount': 0,
        'isEdited': false,
      });

      Map<String, dynamic> unreadCounts =
          Map<String, dynamic>.from(data['unreadCounts'] ?? {});
      for (String userId in participants) {
        if (userId == senderId) continue;
        if (viewingMap[userId] != true) {
          int currentCount = (unreadCounts[userId] as num?)?.toInt() ?? 0;
          unreadCounts[userId] = currentCount + 1;
        }
      }

      transaction.update(conversationRef, {
        'lastMessage': {
          'text': text.trim(),
          'senderId': senderId,
          'timestamp': FieldValue.serverTimestamp()
        },
        'unreadCounts': unreadCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> editMessage(
      String conversationId, String messageId, String newText) async {
    if (newText.trim().isEmpty) return;
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'messageText': newText.trim(),
      'isEdited': true,
    });
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> toggleReaction(
      String conversationId, String messageId, String emoji) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }

      transaction.update(docRef, {
        'reactions': reactions,
        'reactionCount': reactions.length,
      });
    });
  }

  Future<void> setViewingStatus(String conversationId, bool isViewing) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    if (isViewing) {
      await conversationRef.set({
        'currentlyViewing': {uid: true},
        'unreadCounts': {uid: 0}
      }, SetOptions(merge: true));
    } else {
      await conversationRef.set({
        'currentlyViewing': {uid: false}
      }, SetOptions(merge: true));
    }
  }
}
