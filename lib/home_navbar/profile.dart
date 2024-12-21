// profile_page.dart
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/main.dart';
import '../widgets_card/manga_card.dart';
import '../widgets_profile/profile_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<dynamic>> favoriteMangas;
  late Future<List<dynamic>> topRateds;
  late Future<List<dynamic>> allRateds;

  String? _currentUserId;

  int favoritePage = 1;
  int topRatedPage = 1;
  int allRatedPage = 1;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    favoriteMangas = _fetchUserManga('favorites', favoritePage);
    topRateds = _fetchUserManga('toprated', topRatedPage);
    allRateds = _fetchUserManga('allrated', allRatedPage);
  }

  Future<void> delayRequest() async {
    await Future.delayed(Duration(seconds: 1));
  }

  Future<List<dynamic>> _fetchUserManga(String type, int page) async {
    const int itemsPerPage = 5;
    try {
      List<String> mangaIds = [];
      QuerySnapshot userQuery;

      if (type == 'favorites') {
        userQuery = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('manga_ratings')
            .where('isFavorite', isEqualTo: true)
            .get();
        mangaIds = userQuery.docs.map((doc) => doc.id).toList();
      } else if (type == 'toprated') {
        userQuery = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('manga_ratings')
            .where('rating', isGreaterThanOrEqualTo: 9)
            .get();
        mangaIds = userQuery.docs.map((doc) => doc.id).toList();
      } else if (type == 'allrated') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('manga_ratings')
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
                'mal_id': data['mal_id'],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: backgroundColor,
        backgroundColor: primaryColor,
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                UserHeader(auth: _auth),
                Column(
                  children: [
                    buildCategory('Favorites', favoriteMangas, 'favorites'),
                    const SizedBox(height: 20),
                    buildCategory('Top Rated', topRateds, 'toprated'),
                    const SizedBox(height: 20),
                    buildCategory('All Rated', allRateds, 'allrated'),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      favoriteMangas = _fetchUserManga('favorites', favoritePage);
      topRateds = _fetchUserManga('toprated', topRatedPage);
      allRateds = _fetchUserManga('allrated', allRatedPage);
    });
  }

  Widget buildCategory(
      String title, Future<List<dynamic>> data, String categoryType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 1,
          minFontSize: 18,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPlaceholderRow();
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyCategoryMessage(categoryType);
            } else if (snapshot.hasError) {
              return _buildErrorRow();
            } else {
              return _buildMangaList(snapshot.data!);
            }
          },
        ),
        buildPaginationButtons(categoryType),
      ],
    );
  }

  Widget _buildEmptyCategoryMessage(String categoryType) {
    String message = categoryType == 'favorites'
        ? "No favorites yet."
        : categoryType == 'toprated'
            ? "No top rated yet."
            : "No ratings yet.";
    return SizedBox(
      height: 240,
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildMangaList(List<dynamic> data) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length > 5 ? 5 : data.length,
        itemBuilder: (context, index) {
          var manga = data[index];
          return MangaCard(manga: manga, userId: _currentUserId);
        },
      ),
    );
  }

  Widget _buildPlaceholderRow() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) => const MangaCard(isPlaceholder: true),
      ),
    );
  }

  Widget _buildErrorRow() {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 10),
            Text('Failed to load data'),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPaginationButtons(String categoryType) {
    int currentPage = (categoryType == 'favorites')
        ? favoritePage
        : (categoryType == 'toprated')
            ? topRatedPage
            : allRatedPage;

    Future<List<dynamic>> dataToCheck = (categoryType == 'favorites')
        ? favoriteMangas
        : (categoryType == 'toprated')
            ? topRateds
            : allRateds;

    Function onPageChange = (int newPage) {
      setState(() {
        if (categoryType == 'favorites') {
          favoritePage = newPage;
          favoriteMangas = _fetchUserManga('favorites', favoritePage);
        } else if (categoryType == 'toprated') {
          topRatedPage = newPage;
          topRateds = _fetchUserManga('toprated', topRatedPage);
        } else if (categoryType == 'allrated') {
          allRatedPage = newPage;
          allRateds = _fetchUserManga('allrated', allRatedPage);
        }
      });
    };

    return FutureBuilder<List<dynamic>>(
      future: dataToCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        bool canGoToNextPage = snapshot.hasData && snapshot.data!.length == 5;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed:
                  currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
            ),
            Text('Page $currentPage'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed:
                  canGoToNextPage ? () => onPageChange(currentPage + 1) : null,
            ),
          ],
        );
      },
    );
  }
}
