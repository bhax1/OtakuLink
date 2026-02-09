import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  // Singleton pattern to ensure one instance globally
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // RAM Cache: Stores user data to avoid repeated Firestore reads
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    // 1. Check Cache first
    if (_cache.containsKey(userId)) {
      return _cache[userId];
    }

    try {
      // 2. Fetch from Firestore if not in cache
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data();
      
      if (data != null) {
        _cache[userId] = data; // Save to cache
      }
      return data;
    } catch (e) {
      print("Error fetching user $userId: $e");
      return null;
    }
  }

  // Call this on Logout or Pull-to-Refresh
  void clearCache() {
    _cache.clear();
  }
}