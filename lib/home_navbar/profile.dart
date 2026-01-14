import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets_card/viewmanga_card.dart';
import '../widgets_profile/profile_widgets.dart';
import '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;

  int favoritePage = 1;
  int topRatedPage = 1;
  int allRatedPage = 1;

  late Future<List<dynamic>> favoriteMangas;
  late Future<List<dynamic>> topRateds;
  late Future<List<dynamic>> allRateds;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadAllCategories();
  }

  void _loadAllCategories() {
    favoriteMangas = _fetchUserManga('favorites', favoritePage);
    topRateds = _fetchUserManga('toprated', topRatedPage);
    allRateds = _fetchUserManga('allrated', allRatedPage);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadAllCategories();
    });
  }

  Future<List<dynamic>> _fetchUserManga(String type, int page) async {
    const int itemsPerPage = 5;
    try {
      List<String> mangaIds = [];
      QuerySnapshot userQuery;

      // Fetch user manga IDs from Firestore
      if (type == 'favorites') {
        userQuery = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('manga_ratings')
            .where('isFavorite', isEqualTo: true)
            .get();
      } else if (type == 'toprated') {
        userQuery = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('manga_ratings')
            .where('rating', isGreaterThanOrEqualTo: 9)
            .get();
      } else {
        userQuery = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('manga_ratings')
            .get();
      }

      mangaIds = userQuery.docs.map((doc) => doc.id).toList();

      int start = (page - 1) * itemsPerPage;
      if (start >= mangaIds.length) return [];

      List<String> currentPageIds = mangaIds.sublist(
        start,
        (start + itemsPerPage) > mangaIds.length
            ? mangaIds.length
            : start + itemsPerPage,
      );

      List<dynamic> mangaList = [];

      var cacheBox = await Hive.openBox('userMangaCache');

      for (String id in currentPageIds) {
        final cacheKey = 'manga_$id';
        final cachedData = cacheBox.get(cacheKey);

        if (cachedData != null) {
          mangaList.add(Map<String, dynamic>.from(json.decode(cachedData)));
          continue;
        }

        // Fetch from API with retry
        int retries = 0;
        while (retries < 3) {
          try {
            final response = await http
                .get(Uri.parse('https://api.jikan.moe/v4/manga/$id'));

            if (response.statusCode == 200) {
              final data = json.decode(response.body)['data'];
              final mangaData = {
                'title': data['title'] ?? 'Unknown Title',
                'images': data['images'],
                'mal_id': data['mal_id'],
              };

              // Cache it
              await cacheBox.put(cacheKey, json.encode(mangaData));
              mangaList.add(mangaData);
              break;
            } else if (response.statusCode == 429) {
              await Future.delayed(Duration(seconds: 1 + retries));
              retries++;
            } else {
              break;
            }
          } catch (_) {
            retries++;
          }
        }
      }

      return mangaList;
    } catch (_) {
      return [];
    }
  }

  Widget _buildCategory(String title, Future<List<dynamic>> data, String type,
      int currentPage, Function(int) onPageChange) {
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
              return SizedBox(
                height: 240,
                child: Center(
                  child: Text(
                    type == 'favorites'
                        ? "No favorites yet."
                        : type == 'toprated'
                            ? "No top rated yet."
                            : "No ratings yet.",
                    style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              return _buildErrorRow(type);
            } else {
              return Column(
                children: [
                  _buildMangaList(snapshot.data!),
                  _buildPagination(snapshot.data!, currentPage, onPageChange),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMangaList(List<dynamic> data) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          return MangaCard(manga: data[index], userId: _currentUserId);
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
        itemBuilder: (_, __) => const MangaCard(isPlaceholder: true),
      ),
    );
  }

  Widget _buildErrorRow(String type) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 10),
            Text('Failed to load $type'),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(
      List<dynamic> data, int currentPage, Function(int) onPageChange) {
    bool canNext = data.length == 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
        ),
        Text('Page $currentPage'),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: canNext ? () => onPageChange(currentPage + 1) : null,
        ),
      ],
    );
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
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              UserHeader(auth: _auth),
              const SizedBox(height: 20),
              _buildCategory(
                'Favorites',
                favoriteMangas,
                'favorites',
                favoritePage,
                (newPage) => setState(() {
                  favoritePage = newPage;
                  favoriteMangas = _fetchUserManga('favorites', favoritePage);
                }),
              ),
              const SizedBox(height: 20),
              _buildCategory(
                'Top Rated',
                topRateds,
                'toprated',
                topRatedPage,
                (newPage) => setState(() {
                  topRatedPage = newPage;
                  topRateds = _fetchUserManga('toprated', topRatedPage);
                }),
              ),
              const SizedBox(height: 20),
              _buildCategory(
                'All Rated',
                allRateds,
                'allrated',
                allRatedPage,
                (newPage) => setState(() {
                  allRatedPage = newPage;
                  allRateds = _fetchUserManga('allrated', allRatedPage);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}