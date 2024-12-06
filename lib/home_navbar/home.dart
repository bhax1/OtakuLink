import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:otakulink/home_navbar/mangadetails.dart';
import 'package:otakulink/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> popularManga;
  late Future<List<dynamic>> popularManhwa;

  int mangaPage = 1;
  int manhwaPage = 1;

  // Caching data for pagination
  Map<int, List<dynamic>> cachedManga = {};
  Map<int, List<dynamic>> cachedManhwa = {};

  @override
  void initState() {
    super.initState();
    popularManga = _getData('manga', mangaPage);
    popularManhwa = _getData('manhwa', manhwaPage);
  }

  // Fetch data with caching mechanism
  Future<List<dynamic>> _getData(String type, int page) async {
    var box = await Hive.openBox('mangaCache'); // Open a Hive box

    final cacheKey = '$type$page';
    final cachedData = box.get(cacheKey);
    final cachedTimestamp = box.get('$cacheKey-timestamp');

    if (cachedData != null &&
        cachedTimestamp != null &&
        DateTime.now().millisecondsSinceEpoch - cachedTimestamp < 86400000) {
      return List<dynamic>.from(json.decode(cachedData));
    }

    final url =
        'https://api.jikan.moe/v4/top/manga?type=$type&filter=bypopularity&limit=10&page=$page';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body)['data'];

      // Store the fetched data and timestamp in Hive
      box.put(cacheKey, json.encode(data));
      box.put('$cacheKey-timestamp', DateTime.now().millisecondsSinceEpoch);

      return data;
    } else {
      throw Exception('Failed to load $type');
    }
  }

  // Reusable widget for displaying categories (Manga/Manhwa/Manhua)
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
            } else if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
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

  Widget _buildMangaList(List<dynamic> data) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length > 10 ? 10 : data.length,
        itemBuilder: (context, index) {
          var manga = data[index];
          return MangaCard(manga: manga);
        },
      ),
    );
  }

  // Placeholder row while loading
  Widget _buildPlaceholderRow() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (context, index) => const MangaCard(isPlaceholder: true),
      ),
    );
  }

  // Error row when data fails to load
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
                setState(() {
                  popularManga = _getData('manga', mangaPage);
                  popularManhwa = _getData('manhwa', manhwaPage);
                });
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable pagination buttons for manga, manhwa, and manhua
  Widget buildPaginationButtons(String categoryType) {
    int currentPage = (categoryType == 'manga') ? mangaPage : manhwaPage;
    Function onPageChange = (int newPage) {
      setState(() {
        if (categoryType == 'manga') {
          mangaPage = newPage;
          popularManga = _getData('manga', mangaPage);
        } else {
          manhwaPage = newPage;
          popularManhwa = _getData('manhwa', manhwaPage);
        }
      });
    };

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
          onPressed: () => onPageChange(currentPage + 1),
        ),
      ],
    );
  }

  // Refresh function
  Future<void> _refreshData() async {
    setState(() {
      popularManga = _getData('manga', mangaPage);
      popularManhwa = _getData('manhwa', manhwaPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: backgroundColor,
      backgroundColor: primaryColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              buildCategory('Popular Manga', popularManga, 'manga'),
              const SizedBox(height: 20),
              buildCategory('Hottest Manhwa', popularManhwa, 'manhwa'),
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

  const MangaCard({Key? key, this.manga, this.isPlaceholder = false})
      : super(key: key);

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
                      mangaId: manga['mal_id'],
                      userId: FirebaseAuth.instance.currentUser!.uid,
                    );
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.fastOutSlowIn;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
        child: SizedBox(
          width: 130,
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isPlaceholder)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: manga?['images']?['jpg']?['image_url'] ?? '',
                    width: 120,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      width: 120,
                      height: 150,
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 100),
                  ),
                )
              else
                Container(
                  width: 120,
                  height: 150,
                  color: Colors.grey[300],
                ),
              const SizedBox(height: 10),
              if (!isPlaceholder)
                SizedBox(
                  width: 120,
                  child: Text(
                    manga?['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Container(
                  width: 120,
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
