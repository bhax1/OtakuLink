import 'package:cloud_firestore/cloud_firestore.dart';

class DiscussionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPaginatedCommentsStream({
    required int mangaId,
    required int limit,
    required int page,
  }) {
    return _firestore
        .collection('mangaComments')
        .doc(mangaId.toString())
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(limit * page)
        .snapshots();
  }

  Future<int> getTotalCommentsCount(int mangaId) async {
    try {
      final snapshot = await _firestore
          .collection('mangaComments')
          .doc(mangaId.toString())
          .collection('comments')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print("Error fetching comment count: $e");
      return 0;
    }
  }

  Future<int> getCommentPageNumber({
    required int mangaId,
    required String commentId,
    required int itemsPerPage,
  }) async {
    try {
      final collectionRef = _firestore
          .collection('mangaComments')
          .doc(mangaId.toString())
          .collection('comments');

      final targetDoc = await collectionRef.doc(commentId).get();
      if (!targetDoc.exists) return 1;

      final targetTimestamp = targetDoc.data()?['timestamp'];
      if (targetTimestamp == null) return 1;

      final countQuery = await collectionRef
          .where('timestamp', isGreaterThan: targetTimestamp)
          .count()
          .get();

      int itemsNewerThanTarget = countQuery.count ?? 0;
      return (itemsNewerThanTarget / itemsPerPage).floor() + 1;
    } catch (e) {
      print("Error calculating page jump: $e");
      return 1;
    }
  }

  Future<DocumentReference> postComment({
    required int mangaId,
    required String userId,
    required String text,
    Map<String, dynamic>? replyContext,
  }) async {
    return await _firestore
        .collection('mangaComments')
        .doc(mangaId.toString())
        .collection('comments')
        .add({
      'userId': userId,
      'textContent': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'reactionCount': 0,
      if (replyContext != null) 'replyContext': replyContext,
    });
  }

  Future<void> toggleReaction({
    required int mangaId,
    required String commentId,
    required String userId,
    required String emoji,
  }) async {
    final docRef = _firestore
        .collection('mangaComments')
        .doc(mangaId.toString())
        .collection('comments')
        .doc(commentId);

    try {
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
    } catch (e) {
      print("Error toggling reaction: $e");
      rethrow;
    }
  }
}
