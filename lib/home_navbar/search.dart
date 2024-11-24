import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/home_navbar/mangadetails.dart';
import 'package:otakulink/main.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  String selectedCategory = 'Manga';
  bool isLoading = false;
  bool noResultsFound = false;

  Future<void> _search(String query) async {
    FocusScope.of(context).unfocus();
    if (query.isEmpty) return;

    _setLoadingState(true);

    final apiUrl = 'https://api.jikan.moe/v4/manga?type=${selectedCategory.toLowerCase()}&q=$query&sfw=true';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _handleSearchResults(data);
      } else {
        _handleError();
      }
    } catch (_) {
      _handleError();
    } finally {
      _setLoadingState(false);
    }
  }

  void _setLoadingState(bool loading) {
    setState(() {
      isLoading = loading;
      noResultsFound = false;
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
      itemHeight: 50,
      iconEnabledColor: primaryColor,
      dropdownColor: backgroundColor,
      onChanged: (String? newValue) {
        setState(() {
          selectedCategory = newValue!;
        });
      },
      items: ['Manga', 'Manhwa', 'People'].map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  Widget _buildSearchField() {
    return Expanded(
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Search $selectedCategory',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            color: primaryColor,
            onPressed: () => _search(_controller.text),
          ),
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
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
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: _buildImage(result),
              title: Text(result['title']),
              onTap: () => _navigateToMangaDetails(result),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic> result) {
    final imageUrl = result['images']?['jpg']?['image_url'];
    return imageUrl != null
        ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
        : const Icon(Icons.broken_image);
  }

  void _navigateToMangaDetails(Map<String, dynamic> result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailsPage(
          mangaId: result['mal_id'],
          userId: FirebaseAuth.instance.currentUser!.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).unfocus();
        return true;
      },
      child: Scaffold(
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
      ),
    );
  }
}
