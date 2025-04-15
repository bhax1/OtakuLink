import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:otakulink/main.dart';
import '../widgets_card/manga_card.dart';

// Providers for state management
final mangaPageProvider = StateProvider<int>((ref) => 1);
final manhwaPageProvider = StateProvider<int>((ref) => 1);

final mangaDataProvider =
    FutureProvider.family<List<dynamic>, int>((ref, page) async {
  return fetchData('manga', page);
});

final manhwaDataProvider =
    FutureProvider.family<List<dynamic>, int>((ref, page) async {
  return fetchData('manhwa', page);
});

List<String> filters = ['publishing', 'bypopularity', 'favorite'];

Future<List<dynamic>> fetchData(String type, int page) async {
  var box = await Hive.openBox('mangaCache');
  final cacheKey = '$type$page';
  final cachedData = box.get(cacheKey);
  final cachedTimestamp = box.get('$cacheKey-timestamp');

  if (cachedData != null &&
      cachedTimestamp != null &&
      DateTime.now().millisecondsSinceEpoch - cachedTimestamp < 86400000) {
    return List<dynamic>.from(json.decode(cachedData));
  }

  String randomFilter = filters[
      (DateTime.now().millisecondsSinceEpoch ~/ 86400000) % filters.length];

  final url =
      'https://api.jikan.moe/v4/top/manga?type=$type&filter=$randomFilter&limit=10&page=$page';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    var data = json.decode(response.body)['data'];

    final filteredData = (data as List).map((item) {
      return {
        'title': item['title'] ?? 'Unknown Title',
        'images': item['images'],
        'mal_id': item['mal_id'],
      };
    }).toList();

    box.put(cacheKey, json.encode(filteredData));
    box.put('$cacheKey-timestamp', DateTime.now().millisecondsSinceEpoch);

    return filteredData;
  } else {
    throw Exception('Failed to load $type');
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaPage = ref.watch(mangaPageProvider);
    final manhwaPage = ref.watch(manhwaPageProvider);

    final mangaData = ref.watch(mangaDataProvider(mangaPage));
    final manhwaData = ref.watch(manhwaDataProvider(manhwaPage));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mangaDataProvider);
        ref.invalidate(manhwaDataProvider);
      },
      color: backgroundColor,
      backgroundColor: primaryColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              buildCategory(
                  context, ref, 'Popular Manga', mangaData, mangaPageProvider),
              const SizedBox(height: 20),
              buildCategory(context, ref, 'Hottest Manhwa', manhwaData,
                  manhwaPageProvider),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCategory(BuildContext context, WidgetRef ref, String title,
      AsyncValue<List<dynamic>> data, StateProvider<int> pageProvider) {
    final currentPage = ref.watch(pageProvider);
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
        data.when(
          loading: () => _buildPlaceholderRow(),
          error: (error, stack) => _buildErrorRow(ref, pageProvider),
          data: (items) => _buildMangaList(items),
        ),
        buildPaginationButtons(ref, pageProvider, currentPage),
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
          return MangaCard(
              manga: manga, userId: FirebaseAuth.instance.currentUser?.uid);
        },
      ),
    );
  }

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

  Widget _buildErrorRow(WidgetRef ref, StateProvider<int> pageProvider) {
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
                ref.invalidate(pageProvider);
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPaginationButtons(
      WidgetRef ref, StateProvider<int> pageProvider, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: currentPage > 1
              ? () => ref.read(pageProvider.notifier).state--
              : null,
        ),
        TextButton(
          onPressed: () => _showPageInputDialog(ref, pageProvider),
          child: Text(
            'Page $currentPage',
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => ref.read(pageProvider.notifier).state++,
        ),
      ],
    );
  }

  Future<void> _showPageInputDialog(
      WidgetRef ref, StateProvider<int> pageProvider) async {
    TextEditingController pageController = TextEditingController();
    final _formKey = GlobalKey<FormState>(); // Form key for validation
    return showDialog(
      context: ref.context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Page Number'),
          content: Form(
            key: _formKey,
            child: TextSelectionTheme(
              data: TextSelectionThemeData(
                selectionColor: Colors.grey,
                selectionHandleColor: primaryColor,
              ),
              child: TextFormField(
                controller: pageController,
                keyboardType: TextInputType.number,
                cursorColor: accentColor,
                decoration: InputDecoration(
                  hintText: 'Page number',
                  errorText: _formKey.currentState?.validate() == false
                      ? 'Page number must be a valid number greater than 0'
                      : null,
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a page number';
                  }
                  // Check if the value is a valid positive integer and greater than 0
                  final pageNumber = int.tryParse(value);
                  if (pageNumber == null) {
                    return 'Page number must be a valid number';
                  } else if (pageNumber <= 0) {
                    return 'Page number must be greater than 0';
                  }
                  return null; // No error
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                if (_formKey.currentState?.validate() == true) {
                  String input = pageController.text;
                  int newPage = int.parse(input);
                  ref.read(pageProvider.notifier).state = newPage;
                  Navigator.pop(context);
                }
              },
              child: Text(
                'OK',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
  }
}