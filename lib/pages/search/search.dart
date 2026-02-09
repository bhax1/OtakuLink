import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/pages/home/manga_details_page.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
import 'package:otakulink/theme.dart'; 

class SearchPage extends StatefulWidget {
  final Function(int) onTabChange;

  const SearchPage({Key? key, required this.onTabChange}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  // Data
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  bool noResultsFound = false;

  // --- FILTER STATE ---
  String selectedCategory = 'Manga';
  final List<String> categories = ['Manga', 'Manhwa', 'Manhua', 'Novels', 'Users'];

  // Advanced Filters
  String _selectedSort = 'POPULARITY_DESC';
  String? _selectedStatus; // Null means 'Any'
  List<String> _selectedGenres = [];

  String _sanitizeQuery(String input) {
    // Removes double quotes and backslashes which are 
    // dangerous in GraphQL string literals.
    return input.replaceAll(RegExp(r'[\"\\]'), '');
  }

  // Filter Constants
  final Map<String, String> _sortOptions = {
    'Most Popular': 'POPULARITY_DESC',
    'Top Rated': 'SCORE_DESC',
    'Trending': 'TRENDING_DESC',
    'Newest': 'START_DATE_DESC',
    'Oldest': 'START_DATE_ASC',
  };

  final Map<String, String> _statusOptions = {
    'Any Status': '',
    'Releasing': 'RELEASING',
    'Finished': 'FINISHED',
    'Hiatus': 'HIATUS',
    'Upcoming': 'NOT_YET_RELEASED'
  };

  final List<String> _genreList = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 
    'Horror', 'Mecha', 'Mystery', 'Psychological', 'Romance', 
    'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural', 'Thriller'
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- API SEARCH LOGIC ---

  void _onSearchChanged(String query) {
    // 1. Always cancel the previous timer if the user types/deletes
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 2. If the field is empty, clear results immediately and don't start a timer
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
        noResultsFound = false;
      });
      return;
    }

    // 3. Start the delay (increased to 800ms for a smoother experience while deleting)
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _performSearch(query);
    });
  }

  Future<void> _clearHistory() async {
    var box = await Hive.openBox('searchHistory');
    await box.clear();
    setState(() {}); // Refresh the UI to hide the history section
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // STEP 1: SANITIZE THE INPUT
    // Clean the query before it touches any API or Database
    final sanitizedQuery = _sanitizeQuery(query.trim());

    setState(() {
      isLoading = true;
      noResultsFound = false;
    });

    try {
      List<Map<String, dynamic>> results = [];

      if (selectedCategory == 'Users') {
        // STEP 2: USE THE SANITIZED VERSION
        results = await _searchUsers(sanitizedQuery);
      } else {
        results = await _searchAniList(sanitizedQuery, selectedCategory);
        
        // Save to history only on successful AniList search
        if (results.isNotEmpty) {
          await _saveToHistory(sanitizedQuery);
        }
      }

      if (mounted) {
        if (_controller.text.trim() == query.trim()) {
          setState(() {
            searchResults = results;
            noResultsFound = results.isEmpty;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _searchAniList(String query, String category) async {
    const String url = 'https://graphql.anilist.co';
    
    // 1. Build Dynamic Filters
    List<String> filterList = ['sort: [$_selectedSort]'];
    
    // Category logic: Only filter by country/format where strictly necessary
    if (category == 'Novels') {
      filterList.add('format: NOVEL');
    } else if (category == 'Manhwa') {
      filterList.add('countryOfOrigin: "KR"');
    } else if (category == 'Manhua') {
      filterList.add('countryOfOrigin: "CN"');
    } else {
      // Standard Manga: Exclude novels to keep results relevant
      filterList.add('format_not: NOVEL');
    }

    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filterList.add('status: $_selectedStatus');
    }

    if (_selectedGenres.isNotEmpty) {
      String genreString = _selectedGenres.map((g) => '"$g"').join(',');
      filterList.add('genre_in: [$genreString]');
    }

    if (query.trim().isNotEmpty) {
      filterList.add('search: \$search');
    }

    String filters = filterList.join(', ');

    final String graphQLQuery = '''
      query (\$search: String) {
        Page(page: 1, perPage: 12) {
          media(type: MANGA, $filters) {
            id
            title { romaji english }
            coverImage { large }
            averageScore
            startDate { year }
            status
          }
        }
      }
    ''';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({
        'query': graphQLQuery, 
        'variables': {'search': query.trim().isEmpty ? null : query.trim()}
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List media = data['data']['Page']['media'];

      return media.map((item) {
        // 2. Format the Subtitle: Replace format with Status
        String rawStatus = item['status']?.toString() ?? "Unknown";
        // Convert "RELEASING" to "Releasing" for better UI
        String formattedStatus = rawStatus[0] + rawStatus.substring(1).toLowerCase().replaceAll('_', ' ');
        String year = item['startDate']['year']?.toString() ?? "TBA";

        return {
          'type': 'media',
          'id': item['id'], 
          'title': item['title']['english'] ?? item['title']['romaji'],
          'image': item['coverImage']['large'],
          'subtitle': '$year • $formattedStatus', // Now shows "2023 • Releasing"
          'score': item['averageScore'] != null ? (item['averageScore'] / 10.0).toStringAsFixed(1) : null,
          'status': item['status']
        };
      }).toList();
    }
    return [];
  }

  Future<void> _saveToHistory(String query) async {
    if (query.isEmpty) return;
    
    var box = await Hive.openBox('searchHistory');
    List<String> history = box.get('recent', defaultValue: <String>[]);
    
    // Remove if exists to move it to the top, then insert at index 0
    history.remove(query);
    history.insert(0, query);
    
    // Keep only the last 10 searches
    if (history.length > 10) history = history.sublist(0, 10);
    
    await box.put('recent', history);
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    if (query.isEmpty) return []; // Firestore needs a query string
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': 'user',
        'id': doc.id,
        'title': data['username'] ?? 'Unknown',
        'image': data['photoURL'],
        'subtitle': data['bio'] ?? 'No bio available',
      };
    }).toList();
  }

  // --- FILTER UI ---

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) {
        return StatefulBuilder( // Needed to update state inside BottomSheet
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75, // Tall sheet
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Filters", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          // Reset Logic
                          setModalState(() {
                            _selectedSort = 'POPULARITY_DESC';
                            _selectedStatus = null;
                            _selectedGenres.clear();
                          });
                        },
                        child: const Text("Reset", style: TextStyle(color: Colors.redAccent)),
                      )
                    ],
                  ),
                  const Divider(),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Sort By
                          const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children: _sortOptions.keys.map((key) {
                              final isSelected = _selectedSort == _sortOptions[key];
                              return ChoiceChip(
                                label: Text(key),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.primary : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                ),
                                onSelected: (selected) {
                                  setModalState(() => _selectedSort = _sortOptions[key]!);
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // 2. Status
                          const Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus ?? '',
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _statusOptions.keys.map((key) {
                              return DropdownMenuItem(value: _statusOptions[key], child: Text(key));
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => _selectedStatus = (val == '') ? null : val);
                            },
                          ),

                          const SizedBox(height: 20),

                          // 3. Genres
                          const Text("Genres", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _genreList.map((genre) {
                              final isSelected = _selectedGenres.contains(genre);
                              return FilterChip(
                                label: Text(genre),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      _selectedGenres.add(genre);
                                    } else {
                                      _selectedGenres.remove(genre);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close modal
                        _performSearch(_controller.text); // Trigger search
                      },
                      child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    bool areFiltersActive = _selectedGenres.isNotEmpty || _selectedStatus != null || _selectedSort != 'POPULARITY_DESC';

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Header
                Row(
                  children: [
                    // Dropdown (Compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedCategory = val;
                                // Clear generic search if switching to Users to avoid bad queries
                                if (val == 'Users') searchResults.clear();
                              });
                            }
                          },
                          items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Search Field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 22, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          // Clear Button
                          suffixIcon: _controller.text.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  _onSearchChanged('');
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                        ),
                      ),
                    ),

                    // Filter Button (Only show if NOT searching Users)
                    if (selectedCategory != 'Users') ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: areFiltersActive ? AppColors.primary : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.tune, color: areFiltersActive ? Colors.white : Colors.grey[600]),
                          onPressed: _showFilterModal,
                        ),
                      ),
                    ]
                  ],
                ),

                const SizedBox(height: 16),

                // Filter Chips Display (To show what's active)
                if (selectedCategory != 'Users' && areFiltersActive)
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_selectedStatus != null) _buildMiniChip(_statusOptions.entries.firstWhere((e) => e.value == _selectedStatus).key),
                        ..._selectedGenres.map((g) => _buildMiniChip(g)),
                      ],
                    ),
                  ),

                if (selectedCategory != 'Users' && areFiltersActive)
                  const SizedBox(height: 10),

                // Results
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3))
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
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
      );
    }

    if (noResultsFound) {
      return Center(
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
      );
    }

    if (searchResults.isEmpty) {
      return FutureBuilder(
        future: Hive.openBox('searchHistory'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            final box = snapshot.data as Box;
            final List<String> history = box.get('recent', defaultValue: <String>[]);

            if (history.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories, size: 60, color: Colors.grey[200]),
                    const SizedBox(height: 10),
                    Text("Discover something new", style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Clear Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Recent Searches", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)
                    ),
                    TextButton(
                      onPressed: _clearHistory,
                      child: const Text("Clear All", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
                
                // History Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: history.map((term) => ActionChip(
                    label: Text(term, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide.none,
                    onPressed: () {
                      _controller.text = term;
                      _performSearch(term);
                    },
                  )).toList(),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final item = searchResults[index];
        return _buildResultCard(item);
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    bool isUser = item['type'] == 'user';

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(isUser ? 50 : 6),
          child: Container(
            width: 45, height: isUser ? 45 : 65,
            color: Colors.grey[200],
            child: item['image'] != null 
                ? CachedNetworkImage(imageUrl: item['image'], fit: BoxFit.cover)
                : Icon(isUser ? Icons.person : Icons.book, color: Colors.grey),
          ),
        ),
        title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item['subtitle'], style: const TextStyle(fontSize: 12)),
        trailing: (!isUser && item['score'] != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(" ${item['score']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              )
            : null,
        onTap: () {
          if (isUser) {
             final currentUid = FirebaseAuth.instance.currentUser?.uid;
             if (currentUid == item['id']) {
               widget.onTabChange(3); 
             } else {
               Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfilePage(userId: item['id'])));
             }
          } else {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => MangaDetailsPage(
                 mangaId: item['id'],
                 userId: FirebaseAuth.instance.currentUser?.uid ?? '',
               )),
             );
          }
        },
      ),
    );
  }
}