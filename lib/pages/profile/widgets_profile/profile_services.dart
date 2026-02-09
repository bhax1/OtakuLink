import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> delayRequest() async {
    await Future.delayed(Duration(seconds: 1));
  }

  Future<List<dynamic>> fetchUserManga(String userId, String type, int page) async {
    const int itemsPerPage = 5;
    try {
      List<String> mangaIds = [];
      QuerySnapshot userQuery;
      
      if (type == 'favorites') {
        userQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('manga_ratings')
            .where('isFavorite', isEqualTo: true)
            .get();
        mangaIds = userQuery.docs.map((doc) => doc.id).toList();
      } else if (type == 'toprated') {
        userQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('manga_ratings')
            .where('rating', isGreaterThanOrEqualTo: 9)
            .get();
        mangaIds = userQuery.docs.map((doc) => doc.id).toList();
      }

      int start = (page - 1) * itemsPerPage;
      int end = start + itemsPerPage;

      if (start >= mangaIds.length) {
        return [];
      }

      List<String> currentPageIds = mangaIds.sublist(
        start,
        end > mangaIds.length ? mangaIds.length : end,
      );

      List<dynamic> mangaList = [];

      for (String mangaId in currentPageIds) {
        final url = 'https://api.jikan.moe/v4/manga/$mangaId';
        bool success = false;

        while (!success) {
          try {
            final response = await http.get(Uri.parse(url));

            if (response.statusCode == 429) {
              await delayRequest();
              continue;
            }

            if (response.statusCode == 200) {
              var data = json.decode(response.body)['data'];
              mangaList.add({
                'title': data['title'] ?? 'Unknown Title',
                'images': data['images'],
                'id': data['id'],
              });
              success = true;
            } else {
              break;
            }
          } catch (e) {
            break;
          }
        }
      }

      return mangaList;
    } catch (error) {
      return [];
    }
  }
}
