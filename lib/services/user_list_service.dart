import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserListService {
  final FirebaseFirestore _db;

  UserListService({required FirebaseFirestore db}) : _db = db;

  static const String _usersCol = 'users';
  static const String _libraryCol = 'library';

  Future<DocumentSnapshot> getUserMangaEntry(String userId, int mangaId) {
    return _db
        .collection(_usersCol)
        .doc(userId)
        .collection(_libraryCol)
        .doc(mangaId.toString())
        .get();
  }

  Future<void> trackChapterRead({
    required String userId,
    required String mangaId,
    required String chapterId,
    required String mangaTitle,
    required String chapterNum,
    String? imageUrl,
  }) async {
    final userRef = _db.collection(_usersCol).doc(userId);
    final libraryRef = userRef.collection(_libraryCol).doc(mangaId);

    await _db.runTransaction((transaction) async {
      final librarySnap = await transaction.get(libraryRef);
      List<dynamic> readChapters = [];
      String currentStatus = 'Reading';

      if (librarySnap.exists) {
        final data = librarySnap.data() as Map<String, dynamic>;
        readChapters = data['readChapters'] ?? [];
        currentStatus = data['status'] ?? 'Reading';
      }

      if (readChapters.contains(chapterId)) return;

      final Map<String, dynamic> updateData = {
        'mangaId': mangaId,
        'title': mangaTitle,
        'status': currentStatus,
        'lastChapterNum': double.tryParse(chapterNum) ?? 0,
        'lastReadId': chapterId,
        'readChapters': FieldValue.arrayUnion([chapterId]),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null && imageUrl.isNotEmpty) {
        updateData['imageUrl'] = imageUrl;
      }

      transaction.set(libraryRef, updateData, SetOptions(merge: true));

      transaction.update(userRef, {
        'stats.chaptersRead': FieldValue.increment(1),
      });
    });
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
    final userRef = _db.collection(_usersCol).doc(userId);
    final libraryRef = userRef.collection(_libraryCol).doc(mangaId.toString());

    await _db.runTransaction((transaction) async {
      final librarySnap = await transaction.get(libraryRef);
      final userSnap = await transaction.get(userRef);

      if (!userSnap.exists) throw Exception("User not found");

      final userData = userSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> userStats =
          Map<String, dynamic>.from(userData['stats'] ?? {});

      String? oldStatus;
      if (librarySnap.exists) {
        oldStatus = (librarySnap.data() as Map<String, dynamic>)['status'];
      }

      if (oldStatus != status) {
        if (oldStatus != null) {
          String field = _getStatusField(oldStatus);
          if (field.isNotEmpty) userStats[field] = (userStats[field] ?? 0) - 1;
        }
        String newField = _getStatusField(status);
        if (newField.isNotEmpty) {
          userStats[newField] = (userStats[newField] ?? 0) + 1;
        }
      }

      transaction.set(
          libraryRef,
          {
            'mangaId': mangaId.toString(),
            'title': title,
            'rating': rating,
            'isFavorite': isFavorite,
            'status': status,
            'commentary': comment,
            'imageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      transaction.update(userRef, {'stats': userStats});
    });
  }

  Future<void> deleteEntry(String userId, int mangaId) async {
    final userRef = _db.collection(_usersCol).doc(userId);
    final libraryRef = userRef.collection(_libraryCol).doc(mangaId.toString());

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(libraryRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final String? status = data['status'];

      transaction.delete(libraryRef);

      if (status != null) {
        String field = _getStatusField(status);
        if (field.isNotEmpty) {
          transaction
              .update(userRef, {'stats.$field': FieldValue.increment(-1)});
        }
      }
    });
  }

  String _getStatusField(String uiStatus) {
    switch (uiStatus) {
      case 'Completed':
        return 'completed';
      case 'Reading':
        return 'reading';
      case 'Dropped':
        return 'dropped';
      case 'On Hold':
        return 'onHold';
      case 'Plan to Read':
        return 'planned';
      default:
        return '';
    }
  }
}

final userListServiceProvider = Provider<UserListService>((ref) {
  return UserListService(db: FirebaseFirestore.instance);
});
