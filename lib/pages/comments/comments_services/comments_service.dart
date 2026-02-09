import 'package:cloud_firestore/cloud_firestore.dart';

class CommentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream comments for real-time updates
  Stream<QuerySnapshot> getCommentsStream(int mangaId) {
    return _firestore
        .collection('manga_comments')
        .doc(mangaId.toString())
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Add a new comment
  Future<DocumentReference> postComment({
    required int mangaId,
    required String userId,
    required String username,
    required String? userPhoto,
    required String text,
    Map<String, dynamic>? replyContext,
  }) async {
    return await _firestore
        .collection('manga_comments')
        .doc(mangaId.toString())
        .collection('comments')
        .add({
      'userId': userId,
      'username': username,
      'userPhoto': userPhoto,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'reactionCount': 0,
      if (replyContext != null) 'replyContext': replyContext,
    });
  }

  // Toggle reactions (Like, Love, etc.)
  Future<void> toggleReaction({
    required int mangaId,
    required String commentId,
    required String userId,
    required String emoji,
  }) async {
    final docRef = _firestore
        .collection('manga_comments')
        .doc(mangaId.toString())
        .collection('comments')
        .doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (reactions[userId] == emoji) {
        reactions.remove(userId);
      } else {
        reactions[userId] = emoji;
      }

      transaction.update(docRef, {
        'reactions': reactions,
        'reactionCount': reactions.length,
      });
    });
  }
}