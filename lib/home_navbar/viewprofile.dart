import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/home_navbar/message.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/widgets_viewprofile/follow_buttons.dart';
import 'package:otakulink/widgets_viewprofile/friend_buttons.dart';
import 'package:otakulink/widgets_viewprofile/profile_header.dart';
import 'package:otakulink/widgets_viewprofile/profile_service.dart';

import '../widgets_card/viewmanga_card.dart';

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
  String? _userIds;

  late Future<List<dynamic>> favoriteMangas;
  late Future<List<dynamic>> topRateds = Future.value([]);
  late Future<List<dynamic>> allRateds = Future.value([]);

  int favoritePage = 1;
  int topRatedPage = 1;
  int allRatedPage = 1;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _userIds = widget.userId;
    _fetchUserProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Fetch user profile
  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ProfileService.fetchUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
          _initializeData();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user profile.';
        });
      }
    }
  }

  Future<void> _initializeData() async {
    // Wait for favoriteMangas to finish before fetching topRateds
    favoriteMangas = _fetchUserManga('favorites', favoritePage);
    topRateds = _fetchUserManga('toprated', topRatedPage);
    allRateds = _fetchUserManga('allrated', allRatedPage);
  }

  // Delay method to handle rate limiting
  Future<void> _delayRequest() async {
    await Future.delayed(Duration(seconds: 1));
  }

  Future<List<dynamic>> _fetchUserManga(String type, int page) async {
    const int itemsPerPage = 5;
    try {
      List<String> mangaIds = [];
      QuerySnapshot userQuery;
      if (type == 'favorites') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userIds)
            .collection('manga_ratings')
            .where('isFavorite', isEqualTo: true)
            .get();
        mangaIds = userQuery.docs.map((doc) => doc.id).toList();
      } else if (type == 'toprated') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userIds)
            .collection('manga_ratings')
            .where('rating', isGreaterThanOrEqualTo: 9)
            .get();
        mangaIds = userQuery.docs.map((doc) => doc.id).toList();
      } else if (type == 'allrated') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userIds)
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

      // Fetch manga details for the current page
      for (String mangaId in currentPageIds) {
        final url = 'https://api.jikan.moe/v4/manga/$mangaId';
        bool success = false;

        while (!success) {
          try {
            final response = await http.get(Uri.parse(url));
            // Handle rate limiting
            if (response.statusCode == 429) {
              debugPrint('Rate limit hit, waiting...');
              await _delayRequest();
              continue; // Retry the current manga request
            }

            if (response.statusCode == 200) {
              var data = json.decode(response.body)['data'];
              mangaList.add({
                'title': data['title'] ?? 'Unknown Title',
                'images': data['images'],
                'mal_id': data['mal_id'],
              });
              success = true; // Successfully retrieved manga data
            } else {
              debugPrint(
                  'Failed to fetch manga $mangaId: ${response.statusCode}');
              break;
            }
          } catch (e) {
            debugPrint('Failed to fetch manga $mangaId: $e');
            break;
          }
        }
      }
      return mangaList;
    } catch (error) {
      debugPrint('Error fetching user manga: $error');
      return [];
    }
  }

  String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K';
    } else {
      return count.toString();
    }
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
        'followers': formatCount(followers),
        'friends': formatCount(friends),
      };
    });
  }

  // Build the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: backgroundColor,
        backgroundColor: primaryColor,
        onRefresh: _refreshData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _userProfile == null
                    ? const Center(child: Text('User profile not found.'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            ProfileHeader(
                              userProfile: _userProfile!,
                              countsStream: getCountsStream(),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                FriendButtons(
                                  userId: widget.userId,
                                  currentUserId: _currentUserId,
                                ),
                                FollowButtons(
                                  userId: widget.userId,
                                  currentUserId: _currentUserId,
                                ),
                                _buildMessageButton(),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Divider(),
                            const SizedBox(height: 20),
                            Text(
                              _userProfile?['bio'] ?? 'No bio available.',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            Divider(),
                            const SizedBox(height: 20),
                            Column(
                              children: [
                                const SizedBox(height: 20),
                                buildCategory(
                                    'Favorites', favoriteMangas, 'favorites'),
                                const SizedBox(height: 20),
                                buildCategory(
                                    'Top Rated', topRateds, 'toprated'),
                                const SizedBox(height: 20),
                                buildCategory(
                                    'All Rated', allRateds, 'allrated'),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  // Method to refresh the data
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
          return MangaCard(manga: manga, userId: _userIds);
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

  // Build message button
  Widget _buildMessageButton() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.message, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MessengerPage(
                friendId: widget.userId,
                friendName: _userProfile?['username'] ?? 'Unknown',
                friendProfilePic: _userProfile?['photoURL'] ?? '',
              ),
              transitionsBuilder: (_, animation, __, child) {
                const offsetStart = Offset(1.0, 0.0);
                const offsetEnd = Offset.zero;
                const curve = Curves.fastOutSlowIn;
                var tween = Tween(begin: offsetStart, end: offsetEnd)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                    position: animation.drive(tween), child: child);
              },
            ),
          );
        },
      ),
    );
  }
}
