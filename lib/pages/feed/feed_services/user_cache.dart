import 'package:cloud_firestore/cloud_firestore.dart';

class UserCache {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, Stream<Map<String, dynamic>>> _streams = {};

  /// Streams user data while caching it to prevent redundant Firestore reads
  static Stream<Map<String, dynamic>> streamUser(String uid) {
    if (_streams.containsKey(uid)) return _streams[uid]!;

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? {'username': 'Unknown', 'photoURL': ''};
      _cache[uid] = data;
      return data;
    }).asBroadcastStream();

    _streams[uid] = stream;
    return stream;
  }

  static void clearCache() {
    _cache.clear();
    _streams.clear();
  }

  static Map<String, dynamic>? getUserSync(String uid) => _cache[uid];
}
