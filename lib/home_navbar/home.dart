import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:otakulink/home_navbar/mangadetails.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> topManga;
  late Future<List<dynamic>> featuredManga;

  @override
  void initState() {
    super.initState();
    topManga = fetchMangaData('https://api.jikan.moe/v4/top/manga?type=manga&filter=bypopularity&limit=10');
    featuredManga = fetchMangaData('https://api.jikan.moe/v4/top/manga?type=manga&filter=favorite&limit=10');
  }

  // Fetch manga data from the API
  Future<List<dynamic>> fetchMangaData(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load manga');
    }
  }

  // Reusable widget for displaying manga categories
  Widget buildMangaCategory(String title, Future<List<dynamic>> mangaData) {
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
          future: mangaData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildMangaPlaceholderRow(); // Placeholder while loading
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildMangaPlaceholderRow(); // Hollow cards in case of error or no data
            } else {
              return SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: snapshot.data!.length > 10 ? 10 : snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var manga = snapshot.data![index];
                    return MangaCard(manga: manga);
                  },
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMangaPlaceholderRow() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10, // Number of placeholders
        itemBuilder: (context, index) {
          return const MangaCard(isPlaceholder: true); // Placeholder cards
        },
      ),
    );
  }

  // Refresh function
  Future<void> _refreshData() async {
    setState(() {
      topManga = fetchMangaData('https://api.jikan.moe/v4/top/manga?type=manga&filter=bypopularity&limit=10');
      featuredManga = fetchMangaData('https://api.jikan.moe/v4/top/manga?type=manga&filter=favorite&limit=10');
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData, // Calls the refresh function
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              buildMangaCategory('Top Ranking by Popularity', topManga),
              const SizedBox(height: 20),
              buildMangaCategory('Top Rated', featuredManga),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class MangaCard extends StatelessWidget {
  final dynamic manga;
  final bool isPlaceholder;

  const MangaCard({
    Key? key,
    this.manga,
    this.isPlaceholder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaceholder
          ? null
          : () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return MangaDetailsPage(
                      mangaId: manga['mal_id'], // Pass the manga ID
                      userId: FirebaseAuth.instance.currentUser!.uid,
                    );
                  },
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0); // Slide from the right
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                ),
              );
            },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Theme.of(context).cardColor,
        child: SizedBox(
          width: 120,
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isPlaceholder)
                Image.network(
                  manga?['images']?['jpg']?['image_url'] ?? '',
                  width: 150, // Consistent width for images
                  height: 150, // Consistent height for images
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                )
              else
                Container(
                  width: 100,
                  height: 150,
                  color: Colors.grey[300],
                ),
              const SizedBox(height: 10),
              if (!isPlaceholder)
                SizedBox(
                  width: 120,
                  child: Text(
                    manga?['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 16,
                  color: Colors.grey[300],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
