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
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              buildCategory(
                  context, ref, 'Popular Manga', mangaData, mangaPageProvider),
              const SizedBox(height: 30),
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
        _buildCategoryHeader(title, data, currentPage),
        const SizedBox(height: 12),
        data.when(
          loading: () => _buildPlaceholderRow(),
          error: (error, stack) => _buildErrorRow(ref, pageProvider),
          data: (items) => _buildMangaList(items),
        ),
        const SizedBox(height: 12),
        buildPaginationButtons(ref, pageProvider, currentPage),
      ],
    );
  }

  Widget _buildCategoryHeader(
      String title, AsyncValue<List<dynamic>> data, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AutoSizeText(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          maxLines: 1,
        ),
        Row(
          children: [
            const Icon(Icons.bookmark, size: 16, color: Colors.orangeAccent),
            const SizedBox(width: 4),
            Text(
              data.when(
                loading: () => 'Loading...',
                error: (_, __) => '-',
                data: (items) => 'Page $currentPage | ${items.length} items',
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMangaList(List<dynamic> data) {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length > 10 ? 10 : data.length,
        itemBuilder: (context, index) {
          var manga = data[index];
          return MangaCard(
            manga: manga,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderRow() {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (context, index) => const MangaCard(isPlaceholder: true),
      ),
    );
  }

  Widget _buildErrorRow(WidgetRef ref, StateProvider<int> pageProvider) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 32),
            const SizedBox(height: 10),
            const Text('Failed to load data'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(pageProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Retry'),
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
        ElevatedButton(
          onPressed: currentPage > 1
              ? () => ref.read(pageProvider.notifier).state--
              : null,
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor:
                currentPage > 1 ? primaryColor : Colors.grey[300],
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () => _showPageInputDialog(ref, pageProvider),
          child: Text(
            'Page $currentPage',
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () => ref.read(pageProvider.notifier).state++,
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: primaryColor,
          ),
          child: const Icon(Icons.arrow_forward, color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _showPageInputDialog(
      WidgetRef ref, StateProvider<int> pageProvider) async {
    TextEditingController pageController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    return showDialog(
      context: ref.context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Page Number'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: pageController,
              keyboardType: TextInputType.number,
              cursorColor: accentColor,
              decoration: InputDecoration(
                hintText: 'Page number',
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a page number';
                }
                final pageNumber = int.tryParse(value);
                if (pageNumber == null) {
                  return 'Page number must be a valid number';
                } else if (pageNumber <= 0) {
                  return 'Page number must be greater than 0';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                if (_formKey.currentState?.validate() == true) {
                  int newPage = int.parse(pageController.text);
                  ref.read(pageProvider.notifier).state = newPage;
                  Navigator.pop(context);
                }
              },
              child: const Text(
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
