import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/pages/home/manga_widgets/viewmanga_card.dart';
import 'package:otakulink/theme.dart';

// --- WIDGET IMPORTS ---
import 'widgets_profile/profile_widgets.dart'; // UserHeader
import 'widgets_profile/recent_reads_list.dart'; // <--- NEW IMPORT

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;

  // Pagination States
  int favoritePage = 1;
  int topRatedPage = 1;
  int allRatedPage = 1;

  // Futures
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

  // --- DATA FETCHING (Firestore + AniList Batch) ---
  Future<List<dynamic>> _fetchUserManga(String type, int page) async {
    const int itemsPerPage = 5;
    if (_currentUserId == null) return [];

    try {
      // 1. Get IDs from Firestore
      Query query = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('manga_ratings');

      if (type == 'favorites') {
        query = query.where('isFavorite', isEqualTo: true);
      } else if (type == 'toprated') {
        query = query.where('rating', isGreaterThanOrEqualTo: 9);
      }
      // 'allrated' gets everything by default

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return [];

      // Extract IDs (Assuming document ID is the Manga ID)
      List<int> allMangaIds = snapshot.docs
          .map((doc) => int.tryParse(doc.id) ?? 0)
          .where((id) => id > 0)
          .toList();

      // 2. Pagination Logic (Local Slicing)
      int start = (page - 1) * itemsPerPage;
      if (start >= allMangaIds.length) return [];

      int end = start + itemsPerPage;
      if (end > allMangaIds.length) end = allMangaIds.length;

      List<int> pageIds = allMangaIds.sublist(start, end);

      // 3. Batch Fetch from AniList (One Request for all 5 items)
      return await _fetchMangaBatchFromAniList(pageIds);

    } catch (e) {
      debugPrint("Error fetching $type: $e");
      return [];
    }
  }

  Future<List<dynamic>> _fetchMangaBatchFromAniList(List<int> ids) async {
    const String apiUrl = 'https://graphql.anilist.co';
    
    const String query = '''
      query (\$ids: [Int]) {
        Page {
          media(id_in: \$ids, type: MANGA) {
            id
            title { romaji english }
            coverImage { large extraLarge }
            averageScore
            status
            format
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'query': query,
          'variables': {'ids': ids},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> mediaList = data['data']['Page']['media'];

        // Map back to the structure your MangaCard expects
        return mediaList.map((item) {
          return {
            'id': item['id'],
            'title': item['title']['english'] ?? item['title']['romaji'] ?? 'Unknown',
            'images': {
              'jpg': {
                'image_url': item['coverImage']['large'],
                'large_image_url': item['coverImage']['extraLarge'] ?? item['coverImage']['large'],
              }
            },
            'score': (item['averageScore'] ?? 0) / 10.0,
            'status': item['status'],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("AniList Batch Error: $e");
    }
    return [];
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: AppColors.primary,
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER
              UserHeader(auth: _auth),
              
              const SizedBox(height: 20),

              // 2. RECENTLY READ (New Section)
              // Only show if logged in
              if (_currentUserId != null) ...[
                RecentReadsList(userId: _currentUserId!),
                const SizedBox(height: 10),
                const Divider(thickness: 1, color: Colors.grey), // Visual Separator
                const SizedBox(height: 20),
              ],
              
              // 3. FAVORITES
              _buildCategory(
                'Favorites',
                favoriteMangas,
                'favorites',
                favoritePage,
                (p) => setState(() {
                  favoritePage = p;
                  favoriteMangas = _fetchUserManga('favorites', favoritePage);
                }),
              ),
              
              const SizedBox(height: 30),
              
              // 4. TOP RATED
              _buildCategory(
                'Top Rated (9+)',
                topRateds,
                'toprated',
                topRatedPage,
                (p) => setState(() {
                  topRatedPage = p;
                  topRateds = _fetchUserManga('toprated', topRatedPage);
                }),
              ),
              
              const SizedBox(height: 30),
              
              // 5. LIBRARY
              _buildCategory(
                'Library',
                allRateds,
                'allrated',
                allRatedPage,
                (p) => setState(() {
                  allRatedPage = p;
                  allRateds = _fetchUserManga('allrated', allRatedPage);
                }),
              ),
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildCategory(String title, Future<List<dynamic>> data, String type,
      int currentPage, Function(int) onPageChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
               Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const Spacer(),
              // Page Indicator
              if (currentPage > 1)
                 Text("Page $currentPage", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPlaceholderRow();
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(type);
            } else if (snapshot.hasError) {
              return _buildErrorRow(type);
            } else {
              return Column(
                children: [
                  _buildMangaList(snapshot.data!),
                  // Only show controls if we have data
                  _buildPaginationControls(snapshot.data!, currentPage, onPageChange),
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
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return MangaCard(
            manga: data[index], 
            userId: _currentUserId, 
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderRow() {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, __) => const MangaCard(isPlaceholder: true),
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String msg = "No ratings yet.";
    IconData icon = Icons.star_border;

    if (type == 'favorites') {
      msg = "No favorites added yet.";
      icon = Icons.favorite_border;
    } else if (type == 'toprated') {
      msg = "No high-rated manga yet.";
      icon = Icons.thumb_up_alt_outlined;
    }

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorRow(String type) {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text('Could not load $type'),
            TextButton(
              onPressed: () => setState(() => _loadAllCategories()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(
      List<dynamic> data, int currentPage, Function(int) onPageChange) {
    
    // We assume if we got 5 items, there *might* be a next page.
    bool canNext = data.length == 5; 
    
    // Hide controls if we are on page 1 and there is no next page
    if (currentPage == 1 && !canNext) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: currentPage > 1 ? AppColors.primary : Colors.grey[300],
            onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$currentPage', 
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: canNext ? AppColors.primary : Colors.grey[300],
            onPressed: canNext ? () => onPageChange(currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}