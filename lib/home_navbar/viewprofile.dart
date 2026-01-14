import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:otakulink/home_navbar/message.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/widgets_card/viewmanga_card.dart';
import 'package:otakulink/widgets_viewprofile/follow_buttons.dart';
import 'package:otakulink/widgets_viewprofile/friend_buttons.dart';
import 'package:otakulink/widgets_viewprofile/profile_header.dart';
import 'package:otakulink/widgets_viewprofile/profile_service.dart';

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

  late Box userMangaCache;

  late Future<List<dynamic>> favoriteMangas;
  late Future<List<dynamic>> topRateds;
  late Future<List<dynamic>> allRateds;

  int favoritePage = 1;
  int topRatedPage = 1;
  int allRatedPage = 1;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializeCache().then((_) => _fetchUserProfile());
  }

  Future<void> _initializeCache() async {
    userMangaCache = await Hive.openBox('userMangaCache');
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

  Future<void> _initializeData() async {
    favoriteMangas = _fetchUserManga('favorites', favoritePage);
    topRateds = _fetchUserManga('toprated', topRatedPage);
    allRateds = _fetchUserManga('allrated', allRatedPage);
  }

  Future<void> _refreshData() async {
    setState(() {
      favoriteMangas = _fetchUserManga('favorites', favoritePage);
      topRateds = _fetchUserManga('toprated', topRatedPage);
      allRateds = _fetchUserManga('allrated', allRatedPage);
    });
  }

  Future<List<dynamic>> _fetchUserManga(String type, int page) async {
    const int itemsPerPage = 5;
    try {
      List<String> mangaIds = [];
      QuerySnapshot userQuery;

      if (type == 'favorites') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('manga_ratings')
            .where('isFavorite', isEqualTo: true)
            .get();
      } else if (type == 'toprated') {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('manga_ratings')
            .where('rating', isGreaterThanOrEqualTo: 9)
            .get();
      } else {
        userQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
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

      for (String id in currentPageIds) {
        final cacheKey = 'manga_$id';
        final cachedData = userMangaCache.get(cacheKey);

        if (cachedData != null) {
          mangaList.add(Map<String, dynamic>.from(json.decode(cachedData)));
          continue;
        }

        int retries = 0;
        while (retries < 3) {
          try {
            final response =
                await http.get(Uri.parse('https://api.jikan.moe/v4/manga/$id'));

            if (response.statusCode == 200) {
              final data = json.decode(response.body)['data'];
              final mangaData = {
                'title': data['title'] ?? 'Unknown Title',
                'images': data['images'],
                'mal_id': data['mal_id'],
              };
              await userMangaCache.put(cacheKey, json.encode(mangaData));
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
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K';
    } else {
      return count.toString();
    }
  }

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
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
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
                            buildCategory('Favorites', favoriteMangas, 'favorites', favoritePage, (newPage) {
                              setState(() {
                                favoritePage = newPage;
                                favoriteMangas = _fetchUserManga('favorites', favoritePage);
                              });
                            }),
                            const SizedBox(height: 20),
                            buildCategory('Top Rated', topRateds, 'toprated', topRatedPage, (newPage) {
                              setState(() {
                                topRatedPage = newPage;
                                topRateds = _fetchUserManga('toprated', topRatedPage);
                              });
                            }),
                            const SizedBox(height: 20),
                            buildCategory('All Rated', allRateds, 'allrated', allRatedPage, (newPage) {
                              setState(() {
                                allRatedPage = newPage;
                                allRateds = _fetchUserManga('allrated', allRatedPage);
                              });
                            }),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget buildCategory(String title, Future<List<dynamic>> data, String type, int currentPage, Function(int) onPageChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(title, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, minFontSize: 18),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPlaceholderRow();
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyCategoryMessage(type);
            } else if (snapshot.hasError) {
              return _buildErrorRow();
            } else {
              return _buildMangaList(snapshot.data!);
            }
          },
        ),
        _buildPagination(snapshotFuture: data, currentPage: currentPage, onPageChange: onPageChange),
      ],
    );
  }

  Widget _buildEmptyCategoryMessage(String type) {
    String message = type == 'favorites'
        ? "No favorites yet."
        : type == 'toprated'
            ? "No top rated yet."
            : "No ratings yet.";
    return SizedBox(height: 240, child: Center(child: Text(message, style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic))));
  }

  Widget _buildMangaList(List<dynamic> data) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          return MangaCard(manga: data[index], userId: widget.userId);
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

  Widget _buildErrorRow() {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 10),
            const Text('Failed to load data'),
            ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination({required Future<List<dynamic>> snapshotFuture, required int currentPage, required Function(int) onPageChange}) {
    return FutureBuilder<List<dynamic>>(
      future: snapshotFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        bool canNext = snapshot.data!.length == 5;
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
      },
    );
  }

  Widget _buildMessageButton() {
    return Container(
      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
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
                var tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.fastOutSlowIn));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            ),
          );
        },
      ),
    );
  }
}
