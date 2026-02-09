import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/theme.dart';
import '../comments/comments_page.dart';

class UserMangaPage extends StatefulWidget {
  final int mangaId;
  final String userId; // The ID of the user whose profile we are viewing

  const UserMangaPage({Key? key, required this.mangaId, required this.userId})
      : super(key: key);

  @override
  _UserMangaPageState createState() => _UserMangaPageState();
}

class _UserMangaPageState extends State<UserMangaPage> {
  // State
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Data Containers
  Map<String, dynamic>? mangaDetails;
  
  // User Specific Data (Read-Only)
  double _userRating = 0;
  bool _isFavorite = false;
  String _readingStatus = 'Not Yet';
  String _userCommentary = '';
  String _targetUsername = 'User';

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      await Future.wait([
        _fetchMangaDetailsAniList(),
        _fetchTargetUserData(),
      ]);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // --- 1. FETCH MANGA METADATA (ANILIST) ---
  Future<void> _fetchMangaDetailsAniList() async {
    const url = 'https://graphql.anilist.co';
    const query = '''
      query (\$id: Int) {
        Media (id: \$id, type: MANGA) {
          id
          title { romaji english }
          coverImage { extraLarge large }
          bannerImage
          description
          status
          genres
          chapters
          format
          startDate { year month day }
          staff (perPage: 1, sort: RELEVANCE) {
             edges { node { name { full } } }
          }
        }
      }
    ''';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({'query': query, 'variables': {'id': widget.mangaId}}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      mangaDetails = data['data']['Media'];
    } else {
      throw Exception('Failed to load manga metadata');
    }
  }

  // --- 2. FETCH USER RATING (FIRESTORE) ---
  Future<void> _fetchTargetUserData() async {
    // Get username first for the header
    final userProfile = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (userProfile.exists) {
      _targetUsername = userProfile.data()?['username'] ?? 'User';
    }

    // Get the rating
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('manga_ratings')
        .doc(widget.mangaId.toString())
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _userRating = (data['rating'] ?? 0).toDouble();
      _isFavorite = data['isFavorite'] ?? false;
      _readingStatus = data['readingStatus'] ?? 'Not Yet';
      _userCommentary = data['commentary'] ?? '';
    }
  }

  // --- HELPERS ---
  String _parseHtmlString(String htmlString) {
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'reading': return Colors.blue;
      case 'on hold': return Colors.orange;
      case 'dropped': return Colors.red;
      default: return Colors.grey;
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (mangaDetails == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.primary),
        body: Center(child: Text(_errorMessage.isNotEmpty ? _errorMessage : "Manga not found")),
      );
    }

    // Data Extraction
    final title = mangaDetails!['title']['english'] ?? mangaDetails!['title']['romaji'] ?? 'Unknown';
    final coverImage = mangaDetails!['coverImage']['extraLarge'] ?? mangaDetails!['coverImage']['large'];
    final bannerImage = mangaDetails!['bannerImage'];
    final description = _parseHtmlString(mangaDetails!['description'] ?? 'No description.');
    final author = (mangaDetails!['staff']['edges'] as List).isNotEmpty 
        ? mangaDetails!['staff']['edges'][0]['node']['name']['full'] 
        : 'Unknown Author';
    final genres = (mangaDetails!['genres'] as List).join(', ');

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.forum_outlined, color: Colors.white),
                  tooltip: 'Community Comments',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsPage(
                          mangaId: widget.mangaId,
                          mangaName: title,
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        ),
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner or Blurred Cover
                    bannerImage != null 
                        ? CachedNetworkImage(imageUrl: bannerImage, fit: BoxFit.cover)
                        : CachedNetworkImage(imageUrl: coverImage, fit: BoxFit.cover, color: Colors.black.withOpacity(0.6), colorBlendMode: BlendMode.darken),
                    
                    // Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                        ),
                      ),
                    ),

                    // Floating Card Content
                    Positioned(
                      bottom: 20, left: 20, right: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Poster
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: coverImage, width: 100, height: 150, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 15),
                          // Title Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(author, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 5),
                                Text(mangaDetails!['status'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION 1: USER'S OPINION (The Core of this Page) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: const Icon(Icons.person, size: 14, color: Colors.white)),
                        const SizedBox(width: 8),
                        Text(
                          "$_targetUsername's Status",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                        const Spacer(),
                        if (_isFavorite) const Icon(Icons.favorite, color: Colors.red),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox("Rating", "$_userRating", Icons.star_rounded, Colors.amber),
                        Container(height: 30, width: 1, color: Colors.grey[300]),
                        _buildStatBox("Status", _readingStatus, Icons.menu_book_rounded, _getStatusColor(_readingStatus)),
                      ],
                    ),
                    
                    if (_userCommentary.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("COMMENTARY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(_userCommentary, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // --- SECTION 2: MANGA INFO ---
              const Text("Synopsis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5)),
              
              const SizedBox(height: 20),
              
              const Text("Genres", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(genres, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}