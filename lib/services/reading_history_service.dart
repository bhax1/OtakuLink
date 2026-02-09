import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ReadingHistoryService {
  static const String _boxName = 'reading_history';

  // 1. Initialize & Sync (Call this in main.dart)
  static Future<void> initAndSync() async {
    await Hive.openBox(_boxName);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Pull history from Cloud to Local
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .get();

        final box = Hive.box(_boxName);
        for (var d in doc.docs) {
          // Sync cloud data to local Hive box
          await box.put(d.id, d.data()['readAt']); 
        }
      } catch (e) {
        print("Sync Error: $e");
      }
    }
  }

  // 2. Mark as Read (Cloud + Local)
  static Future<void> markAsRead({
    required String chapterId,
    required String mangaId,
    required String mangaTitle,  // New
    required String coverUrl,    // New
    required String chapterNum,  // New
  }) async {
    // A. Local Cache (For graying out chapters)
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
    final box = Hive.box(_boxName);
    await box.put(chapterId, DateTime.now().millisecondsSinceEpoch);

    // B. Cloud Sync (For cross-device history) & SOCIAL RECENT READS
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Save specific chapter read (Private/Detailed history)
      final chapterRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .doc(chapterId);
          
      batch.set(chapterRef, {
        'mangaId': mangaId,
        'readAt': FieldValue.serverTimestamp(),
        'chapterId': chapterId,
      });

      // 2. Update "Recently Read" List (Public/Social Profile)
      // This overwrites the entry so the manga bumps to the top of the list
      final recentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_reads')
          .doc(mangaId);

      batch.set(recentRef, {
        'mangaId': mangaId,
        'title': mangaTitle,
        'cover': coverUrl,
        'lastChapter': chapterNum,
        'lastReadAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    }
  }

  // 3. Check if Read (Fast Local Check)
  static bool isRead(String chapterId) {
    if (!Hive.isBoxOpen(_boxName)) return false;
    final box = Hive.box(_boxName);
    return box.containsKey(chapterId);
  }

  static Future<void> clearHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get all documents in the collection
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_reads');
      
      final snapshots = await collection.get();
      
      // Delete them one by one in a batch
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    
    // Clear Local Hive too
    final box = Hive.box(_boxName);
    await box.clear();
  }
}