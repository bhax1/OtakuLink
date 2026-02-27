import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';

class SettingsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Updates a setting in both Firestore and the local Hive cache.
  static Future<void> updateSetting(String key, dynamic value) async {
    // 1. Update Local Cache Instantly (UI reacts immediately)
    await LocalCacheService.updateLocalSetting(key, value);

    // 2. Sync to Cloud
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'settings.$key': value, // Dot notation updates just this specific key
        });
      } catch (e) {
        print("Failed to sync setting '$key' to cloud: $e");
        // Optional: You could revert the local cache here if the cloud write fails
      }
    }
  }
}
