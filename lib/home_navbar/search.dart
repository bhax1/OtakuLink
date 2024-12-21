import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/home_navbar/mangadetails.dart';
import 'package:otakulink/home_navbar/viewprofile.dart';
import 'package:otakulink/main.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  final Function(int) onTabChange;

  const SearchPage({Key? key, required this.onTabChange}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> searchResults = [];
  String selectedCategory = 'Manga';
  bool isLoading = false;
  bool noResultsFound = false;

  void _setLoadingState(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

  void _handleSearchResults(List<Map<String, dynamic>> results) {
    setState(() {
      searchResults = results;
      noResultsFound = results.isEmpty;
    });
  }

  void _handleError() {
    setState(() {
      searchResults = [];
      noResultsFound = true;
    });
  }

  Future<void> _search(String query) async {
    _focusNode.unfocus();
    if (query.isEmpty) return;

    _setLoadingState(true);

    try {
      if (selectedCategory == 'Users') {
        final usersCollection = FirebaseFirestore.instance.collection('users');
        final querySnapshot = await usersCollection
            .where('username', isGreaterThanOrEqualTo: query)
            .where('username', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        final results = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'username': data['username'],
            'photoURL': data['photoURL'],
            'userID': doc.id,
          };
        }).toList();

        _handleSearchResults(results);
      } else {
        final apiUrl =
            'https://api.jikan.moe/v4/manga?type=${selectedCategory.toLowerCase()}&q=$query&sfw=true';
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = (data['data'] as List).map((item) {
            return {
              'title': item['title'] ?? 'Unknown Title',
              'images': item['images'],
              'mal_id': item['mal_id'],
            };
          }).toList();
          _handleSearchResults(results);
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
            _controller.clear();
            searchResults = [];
            noResultsFound = false;
          });
        }
      },
      items: ['Manga', 'Manhwa', 'Users']
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
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          selectionColor: Colors.grey,
          selectionHandleColor: primaryColor,
        ),
        child: TextField(
          focusNode: _focusNode,
          controller: _controller,
          style: TextStyle(color: textColor),
          cursorColor: accentColor,
          decoration: InputDecoration(
            labelText: 'Search $selectedCategory',
            labelStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
          if (selectedCategory == 'Users') {
            return Card(
              color: secondaryColor,
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
                    widget.onTabChange(3); // Navigate to Profile tab
                  } else {
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
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: secondaryColor,
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
      placeholder: (context, url) => const Icon(null),
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
        child: GestureDetector(
          onTap: () {
            _focusNode.unfocus();
          },
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
      ),
    );
  }
}
