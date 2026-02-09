import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  static Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data();
  }
}
