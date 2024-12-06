import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/home_navbar/mangadetails.dart';
import 'package:otakulink/home_navbar/viewprofile.dart';
import 'package:otakulink/main.dart';

class SearchPage extends StatefulWidget {
  final Function(int) onTabChange;

  const SearchPage({Key? key, required this.onTabChange}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  String selectedCategory = 'Manga';
  bool isLoading = false;
  bool noResultsFound = false;
  late Box searchBox;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    searchBox = await Hive.openBox('searchResultsBox');
  }

  // Cache key format: 'searchQuery_timestamp'
  Future<void> _search(String query) async {
    FocusScope.of(context).unfocus();
    if (query.isEmpty) return;

    _setLoadingState(true);

    // Skip cache for 'People' category
    if (selectedCategory != 'People') {
      var cachedResults = searchBox.get(query);
      if (cachedResults != null) {
        // Get the cached data and timestamp
        final cacheData = jsonDecode(cachedResults);
        final cachedTime = DateTime.parse(cacheData['timestamp']);

        // Check if the cache is older than 1 day
        if (DateTime.now().difference(cachedTime).inDays < 1) {
          // If cache is valid, use it
          setState(() {
            searchResults = List<Map<String, dynamic>>.from(cacheData['data']);
            noResultsFound = searchResults.isEmpty;
          });
          _setLoadingState(false);
          return;
        } else {
          // If cache is older than 1 day, delete it
          await searchBox.delete(query);
        }
      }
    }

    try {
      if (selectedCategory == 'People') {
        // Firestore query for users
        final usersCollection = FirebaseFirestore.instance.collection('users');
        final querySnapshot = await usersCollection
            .where('username', isGreaterThanOrEqualTo: query)
            .where('username', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        setState(() {
          searchResults = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'username': data['username'],
              'photoURL': data['photoURL'],
              'userID': doc.id,
            };
          }).toList();
          noResultsFound = searchResults.isEmpty;
        });
      } else {
        // Existing Manga/Manhwa API search logic
        final apiUrl =
            'https://api.jikan.moe/v4/manga?type=${selectedCategory.toLowerCase()}&q=$query&sfw=true';
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _handleSearchResults(data);

          // Cache results for Manga/Manhwa with timestamp
          final cacheData = {
            'data': searchResults,
            'timestamp': DateTime.now().toIso8601String(), // Add timestamp
          };
          searchBox.put(query, jsonEncode(cacheData));
        } else {
          _handleError();
        }
      }
    } catch (error) {
      _handleError();
    } finally {
      _setLoadingState(false);
    }
  }

  void _setLoadingState(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

  void _handleSearchResults(Map<String, dynamic> data) {
    setState(() {
      searchResults = (data['data'] as List)
          .map((item) => {
                'title': item['title'] ?? 'Unknown Title',
                'images': item['images'],
                'mal_id': item['mal_id'],
              })
          .toList();
      noResultsFound = searchResults.isEmpty;
    });
  }

  void _handleError() {
    setState(() {
      searchResults = [];
      noResultsFound = true;
    });
  }

  Widget _buildCategoryDropdown() {
    return DropdownButton<String>(
      value: selectedCategory,
      alignment: Alignment.center,
      iconEnabledColor: primaryColor,
      dropdownColor: backgroundColor,
      style: TextStyle(color: textColor),
      underline: Container(
        height: 2,
        color: accentColor,
      ),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            selectedCategory = newValue;
            _controller.clear(); // Clear the search input
            searchResults = []; // Clear the results
            noResultsFound = false; // Reset no results state
          });
        }
      },
      items: ['Manga', 'Manhwa', 'People']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchField() {
    return Expanded(
      child: TextField(
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: 'Search $selectedCategory',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            color: accentColor,
            onPressed: () => _search(_controller.text),
          ),
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isLoading) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/gif/loading.gif',
                height: 200,
              ),
              const SizedBox(height: 10),
              const Text(
                "Searching...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (noResultsFound) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/pic/sorry.png', width: 200, height: 200),
              const SizedBox(height: 10),
              const Text(
                "Can't find what you're looking for",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final result = searchResults[index];
          if (selectedCategory == 'People') {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: result['photoURL'] != null
                      ? CachedNetworkImageProvider(result['photoURL'])
                      : const AssetImage('assets/pic/default_avatar.png')
                          as ImageProvider,
                ),
                title: Text(result['username'] ?? 'Unknown User'),
                onTap: () {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null &&
                      currentUser.uid == result['userID']) {
                    // Navigate to the Profile tab
                    widget.onTabChange(
                        3); // Assuming the profile page is at index 2
                  } else {
                    // Navigate to the ViewProfilePage
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return ViewProfilePage(
                            userId: result['userID'],
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
                  }
                },
              ),
            );
          } else {
            // Existing Manga/Manhwa result card
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: _buildImage(result),
                title: Text(result['title'] ?? 'Unknown Title'),
                onTap: () => _navigateToMangaDetails(result),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic> result) {
    final imageUrl = result['images']?['jpg']?['image_url'];
    return CachedNetworkImage(
      imageUrl: imageUrl ?? '',
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
    );
  }

  void _navigateToMangaDetails(Map<String, dynamic> result) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return MangaDetailsPage(
            mangaId: result['mal_id'],
            userId: FirebaseAuth.instance.currentUser!.uid,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                _buildCategoryDropdown(),
                const SizedBox(width: 10),
                _buildSearchField(),
              ],
            ),
            const SizedBox(height: 10),
            _buildSearchResults(),
          ],
        ),
      ),
    );
  }
}
