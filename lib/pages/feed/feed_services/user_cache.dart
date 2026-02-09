import 'package:cloud_firestore/cloud_firestore.dart';

class UserCache {
  // Returns a stream of user data. 
  // This ensures if a user changes their pfp, it updates everywhere in the app instantly.
  static Stream<Map<String, dynamic>> streamUser(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }
}