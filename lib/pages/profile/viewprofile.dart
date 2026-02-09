import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/pages/chat/message.dart';
import 'package:otakulink/pages/home/manga_widgets/viewmanga_card.dart';
import 'package:otakulink/pages/profile/widgets_profile/recent_reads_list.dart'; 
import 'package:otakulink/pages/profile/widgets_viewprofile/follow_buttons.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/friend_buttons.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/profile_header.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/profile_service.dart';
import 'package:otakulink/theme.dart';

class ViewProfilePage extends StatefulWidget {
  final String userId;
  const ViewProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  // Data Futures
  late Future<List<dynamic>> favoriteMangas;
  late Future<List<dynamic>> topRateds;
  late Future<List<dynamic>> allRateds;

  // Pagination States
  int favoritePage = 1;
  int topRatedPage = 1;
  int allRatedPage = 1;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ProfileService.fetchUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _isLoading = false;
        _initializeData();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load user profile.';
      });
    }
  }

  void _initializeData() {
    favoriteMangas = _fetchUserManga('favorites', favoritePage);
    topRateds = _fetchUserManga('toprated', topRatedPage);
    allRateds = _fetchUserManga('allrated', allRatedPage);
  }

  Future<void> _refreshData() async {
    setState(() {
      _fetchUserProfile();
      _initializeData();
    });
  }

  // --- OPTIMIZED BATCH FETCHING (AniList) ---

  Future<List<dynamic>> _fetchUserManga(String type, int page) async {
    const int itemsPerPage = 5;
    try {
      // 1. Query Firestore for THIS USER'S ratings
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId) // Querying the user we are VIEWING
          .collection('manga_ratings');

      if (type == 'favorites') {
        query = query.where('isFavorite', isEqualTo: true);
      } else if (type == 'toprated') {
        query = query.where('rating', isGreaterThanOrEqualTo: 9);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return [];

      // 2. Extract Manga IDs
      List<int> allMangaIds = snapshot.docs
          .map((doc) => int.tryParse(doc.id) ?? 0)
          .where((id) => id > 0)
          .toList();

      // 3. Apply Pagination Locally
      int start = (page - 1) * itemsPerPage;
      if (start >= allMangaIds.length) return [];

      int end = start + itemsPerPage;
      if (end > allMangaIds.length) end = allMangaIds.length;

      List<int> pageIds = allMangaIds.sublist(start, end);

      // 4. Fetch Details from AniList in ONE Request
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

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_userProfile?['username'] ?? 'Profile', style: const TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: AppColors.primary,
        onRefresh: _refreshData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16), // Matched padding to ProfilePage
                    child: Column(
                      children: [
                        // Profile Header
                        ProfileHeader(
                          userProfile: _userProfile!,
                          countsStream: getCountsStream(),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Action Buttons (Friend/Follow/Message)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FriendButtons(userId: widget.userId, currentUserId: _currentUserId),
                            FollowButtons(userId: widget.userId, currentUserId: _currentUserId),
                            _buildMessageButton(),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        const Divider(),
                        
                        // Bio Section
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _userProfile?['bio'] ?? 'No bio available.',
                            style: TextStyle(fontSize: 16, color: Colors.grey[800], fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20), // Matched spacing

                        // RECENTLY READ (New Section)
                        RecentReadsList(userId: widget.userId),
                        const SizedBox(height: 10),
                        const Divider(thickness: 1, color: Colors.grey), // Visual Separator
                        const SizedBox(height: 20),

                        // Manga Sections (Favorites)
                        _buildCategory(
                          'Favorites', 
                          favoriteMangas, 
                          'favorites', 
                          favoritePage, 
                          (p) => setState(() {
                            favoritePage = p;
                            favoriteMangas = _fetchUserManga('favorites', favoritePage);
                          })
                        ),

                        const SizedBox(height: 30),

                        // Manga Sections (Top Rated)
                        _buildCategory(
                          'Top Rated (9+)', 
                          topRateds, 
                          'toprated', 
                          topRatedPage, 
                          (p) => setState(() {
                            topRatedPage = p;
                            topRateds = _fetchUserManga('toprated', topRatedPage);
                          })
                        ),

                        const SizedBox(height: 30),

                        // Manga Sections (Library / All Rated)
                        _buildCategory(
                          'Library', 
                          allRateds, 
                          'allrated', 
                          allRatedPage, 
                          (p) => setState(() {
                            allRatedPage = p;
                            allRateds = _fetchUserManga('allrated', allRatedPage);
                          })
                        ),
                        
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
      ),
    );
  }

  // Updated to match ProfilePage UI
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const Spacer(),
              // Mini pagination indicators
               FutureBuilder<List<dynamic>>(
                future: data,
                builder: (context, snapshot) {
                   if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                   return Text(
                     "Page $currentPage",
                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                   );
                }
               )
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
              return const SizedBox(height: 100, child: Center(child: Icon(Icons.error_outline, color: Colors.red)));
            } else {
              return Column(
                children: [
                  _buildMangaList(snapshot.data!),
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
          // IMPORTANT: We use widget.userId here to show the VIEWED user's rating, not our own
          return MangaCard(
            manga: data[index], 
            userId: widget.userId 
          );
        },
      ),
    );
  }

  // Updated to match ProfilePage UI (Right aligned, styled box)
  Widget _buildPaginationControls(
      List<dynamic> data, int currentPage, Function(int) onPageChange) {
    bool canNext = data.length == 5; 
    
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

  // Updated to match ProfilePage UI (Styled container instead of simple text)
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

  Widget _buildMessageButton() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[100], // Soft background
      shape: BoxShape.circle,
      border: Border.all(color: Colors.grey[300]!), // Subtle border
    ),
    child: IconButton(
      icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
      splashRadius: 24,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessengerPage(
              friendId: widget.userId,
              friendName: _userProfile?['username'] ?? 'Unknown',
              friendProfilePic: _userProfile?['photoURL'] ?? '',
            ),
          ),
        );
      },
    ),
  );
}

  Stream<Map<String, String>> getCountsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      final followers = data?['followersCount'] ?? 0;
      final friends = data?['friendsCount'] ?? 0;
      return {
        'followers': _formatCount(followers),
        'friends': _formatCount(friends),
      };
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}