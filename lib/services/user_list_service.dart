import 'package:cloud_firestore/cloud_firestore.dart';

class UserListService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DocumentSnapshot> getUserMangaEntry(String userId, int mangaId) {
    return _db.collection('users')
        .doc(userId)
        .collection('manga_ratings')
        .doc(mangaId.toString())
        .get();
  }

  Future<void> saveEntry({
    required String userId,
    required int mangaId,
    required double rating,
    required bool isFavorite,
    required String status,
    required String comment,
    required String title,
    required String? imageUrl,
  }) async {
    await _db.collection('users')
        .doc(userId)
        .collection('manga_ratings')
        .doc(mangaId.toString())
        .set({
      'rating': rating,
      'isFavorite': isFavorite,
      'readingStatus': status,
      'commentary': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'title': title,
      'image': imageUrl,
    }, SetOptions(merge: true));
  }

  Future<void> deleteEntry(String userId, int mangaId) async {
    await _db.collection('users')
        .doc(userId)
        .collection('manga_ratings')
        .doc(mangaId.toString())
        .delete();
  }
}