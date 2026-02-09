// ... [Keep your existing imports] ...
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/home/person_list_page.dart';
import 'package:otakulink/pages/comments/comments_page.dart';
import 'package:otakulink/pages/home/manga_widgets/person_card.dart';
import 'package:otakulink/theme.dart';
import 'package:otakulink/services/anilist_service.dart';
import 'package:otakulink/services/user_list_service.dart';

// --- NEW IMPORTS ---
import 'package:otakulink/pages/reader/reader_page.dart';
import 'package:otakulink/services/mangadex_service.dart';
import 'package:otakulink/services/reading_history_service.dart';

class MangaDetailsPage extends StatefulWidget {
  final int mangaId;
  final String userId;

  const MangaDetailsPage({
    Key? key,
    required this.mangaId,
    required this.userId
  }) : super(key: key);

  @override
  State<MangaDetailsPage> createState() => _MangaDetailsPageState();
}

class _MangaDetailsPageState extends State<MangaDetailsPage> {
  // ... [Keep your existing state variables: _dbService, _isLoading, etc.] ...
  final UserListService _dbService = UserListService();
  bool _isLoading = true;
  bool _existsInUserList = false;
  Map<String, dynamic>? mangaDetails;
  
  // Form State
  double _rating = 0;
  bool _isFavorite = false;
  String _readingStatus = 'Not Yet';
  final TextEditingController _commentController = TextEditingController();

  // Original State
  double _origRating = 0;
  bool _origFavorite = false;
  String _origStatus = 'Not Yet';
  String _origComment = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // ... [Keep _navigateToPersonList] ...
  void _navigateToPersonList(String pageTitle, bool isStaff, List items) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PersonListPage(
            mangaId: widget.mangaId,
            title: pageTitle,
            isStaff: isStaff,
            initialItems: items,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // --- NEW: LOGIC TO READ MANGA ---
  void _openChapterList() async {
    final title = mangaDetails?['title']['english'] ?? mangaDetails?['title']['romaji'];
    if (title == null) return;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    final dexId = await MangaDexService.searchMangaId(title);
    
    if (mounted) Navigator.pop(context); // Close loading

    if (dexId != null) {
      if (!mounted) return;
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator())
      );
      
      final chapters = await MangaDexService.getChapters(dexId);
      
      if (mounted) Navigator.pop(context); 

      if (chapters.isEmpty) {
        _showDialog("Info", "Manga found, but no English chapters available.");
        return;
      }

      if (mounted) _showChapterSheet(chapters);
    } else {
      _showDialog("Not Found", "Could not find '$title' on MangaDex.");
    }
  }

  void _showChapterSheet(List<Map<String, dynamic>> chapters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Select Chapter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            
            // CREDIT NOTICE
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: Colors.grey[100],
              child: const Text(
                "Powered by MangaDex • Support the Scanlation Groups",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: chapters.length,
                separatorBuilder: (_,__) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final ch = chapters[i];
                  // CHECK HISTORY
                  final bool isRead = ReadingHistoryService.isRead(ch['id'].toString());

                  return ListTile(
                    title: Text("Chapter ${ch['chapter']}", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRead ? Colors.grey : Colors.black
                      )
                    ),
                    subtitle: Text("${ch['group']} • ${ch['title']}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? Colors.grey[400] : Colors.grey[600]
                      )
                    ),
                    trailing: Icon(Icons.chevron_right, color: isRead ? Colors.grey[300] : Colors.grey),
                    leading: isRead ? const Icon(Icons.check, color: Colors.green, size: 16) : null,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReaderPage(
                          initialChapterIndex: i, 
                          allChapters: chapters,
                          mangaId: widget.mangaId.toString(),
                          mangaTitle: mangaDetails?['title']['english'] ?? mangaDetails?['title']['romaji'] ?? 'Unknown',
                          mangaCover: mangaDetails?['coverImage']['large'] ?? '',
                        )
                      ));
                      setState(() {});
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... [Keep your existing _loadData, _saveChanges, _deleteEntry] ...
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        AniListService.getMangaDetails(widget.mangaId),
        _dbService.getUserMangaEntry(widget.userId, widget.mangaId),
      ]);
      // ... [rest of _loadData logic] ...
      final apiData = results[0] as Map<String, dynamic>?;
      final userDoc = results[1] as dynamic;

      if (mounted) {
        setState(() {
          mangaDetails = apiData;
          if (userDoc.exists) {
            _existsInUserList = true;
            final data = userDoc.data() as Map<String, dynamic>;
            _rating = (data['rating'] ?? 0).toDouble();
            _isFavorite = data['isFavorite'] ?? false;
            _readingStatus = data['readingStatus'] ?? 'Not Yet';
            _commentController.text = data['commentary'] ?? '';
            _origRating = _rating;
            _origFavorite = _isFavorite;
            _origStatus = _readingStatus;
            _origComment = _commentController.text;
          } else {
             _existsInUserList = false;
             _rating = 0;
             _isFavorite = false;
             _readingStatus = 'Not Yet';
             _commentController.clear();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
      // ... [rest of _saveChanges logic] ...
       if (_existsInUserList) {
        if (_rating == _origRating &&
            _isFavorite == _origFavorite &&
            _readingStatus == _origStatus &&
            _commentController.text == _origComment) {
          _showDialog('Notice', 'No changes detected.');
          return;
        }
      }
      try {
        await _dbService.saveEntry(
          userId: widget.userId,
          mangaId: widget.mangaId,
          rating: _rating,
          isFavorite: _isFavorite,
          status: _readingStatus,
          comment: _commentController.text,
          title: mangaDetails?['title']['english'] ?? mangaDetails?['title']['romaji'] ?? 'Unknown',
          imageUrl: mangaDetails?['coverImage']['large'],
        );
        setState(() {
          _origRating = _rating;
          _origFavorite = _isFavorite;
          _origStatus = _readingStatus;
          _origComment = _commentController.text;
          _existsInUserList = true;
        });
        _showDialog('Success', 'List updated successfully!');
      } catch (e) {
        _showDialog('Error', 'Failed to save: $e');
      }
  }

  Future<void> _deleteEntry() async {
    // ... [rest of _deleteEntry logic] ...
     final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from List?'),
        content: const Text('This will delete your rating and status.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _dbService.deleteEntry(widget.userId, widget.mangaId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        _showDialog('Error', 'Delete failed: $e');
      }
    }
  }

  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]
      )
    );
  }

  // ... [Keep your helpers: _formatDate, _parseHtml, _getMediaType] ...
  String _formatDate(Map<String, dynamic>? dateData) {
    if (dateData == null || dateData['year'] == null) return '?';
    return '${dateData['year']}-${(dateData['month'] ?? 0).toString().padLeft(2, '0')}';
  }
  String _parseHtml(String htmlString) {
    return htmlString.replaceAll(RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true), '');
  }
  String _getMediaType(String? countryCode) {
    switch (countryCode) {
      case 'KR': return 'Manhwa';
      case 'CN': return 'Manhua';
      case 'JP': return 'Manga';
      default: return 'Manga';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... [Keep basic Scaffold & AnimatedSwitcher] ...
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), 
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeOut,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: _isLoading ? _buildSkeleton() : _buildContent(),
        ),
      ),
    );
  }

  // ... [Keep _buildSkeleton] ...
   Widget _buildSkeleton() {
    return CustomScrollView(
      key: const ValueKey('Skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          backgroundColor: Colors.grey[300],
          pinned: true,
          leading: const BackButton(color: Colors.grey),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [Container(color: Colors.grey[300])],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (mangaDetails == null) return const Center(key: ValueKey('Error'), child: Text("Manga not found"));

    final m = mangaDetails!;
    final title = m['title']['english'] ?? m['title']['romaji'] ?? 'Unknown';
    final cover = m['coverImage']['extraLarge'] ?? m['coverImage']['large'];
    final banner = m['bannerImage'];
    final desc = _parseHtml(m['description'] ?? 'No description.');
    final characters = m['characters']['edges'] as List;
    final staff = m['staff']['edges'] as List;
    final recommendations = m['recommendations']['nodes'] as List;
    final List genres = m['genres'] ?? [];
    final String avgScore = m['averageScore'] != null ? "${m['averageScore']}%" : "N/A";

    return CustomScrollView(
      key: const ValueKey('Content'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          // ... [Keep existing properties] ...
          expandedHeight: 380,
          pinned: true,
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.forum, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsPage(mangaId: widget.mangaId, userId: widget.userId, mangaName: title,))),
            ),
            if (_existsInUserList)
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _deleteEntry),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: banner ?? cover,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.primary),
                  fadeInDuration: const Duration(milliseconds: 800),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.black.withOpacity(0.6)],
                    ),
                  ),
                ),
                Center(
                  child: Hero(
                    tag: 'manga_${m['id']}',
                    child: Container(
                      margin: const EdgeInsets.only(top: 60),
                      height: 220, width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[200])),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
                ),
                const SizedBox(height: 16),
                
                if (genres.isNotEmpty)
                  Center(
                    child: Wrap(
                      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                      children: genres.map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                        child: Text(g, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ),
                
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[100]!)),
                  child: Column(
                    children: [
                      _buildInfoRow('Average Score', avgScore),
                      _buildInfoRow('Status', m['status'] ?? '?'),
                      _buildInfoRow('Chapters', m['chapters']?.toString() ?? 'Ongoing'),
                      _buildInfoRow('Type', _getMediaType(m['countryOfOrigin'])),
                      if (m['volumes'] != null) _buildInfoRow('Volumes', m['volumes'].toString()),
                      _buildInfoRow('Released', _formatDate(m['startDate'])),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                const Text("Synopsis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 12),
                Text(desc, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800])),

                const SizedBox(height: 32),
                const Divider(height: 1),
                const SizedBox(height: 32),
                
                // --- READ BUTTON SECTION (UPDATED) ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.menu_book, color: Colors.white),
                        label: const Text('READ NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange, 
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: _openChapterList, // Calls the new function
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text("Chapter data provided by MangaDex", style: TextStyle(color: Colors.grey[500], fontSize: 10, fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 20),
                // -------------------------------------

                // ... [Keep Characters, Staff, Status Control, Recommendations sections] ...
                if (characters.isNotEmpty) ...[
                  _buildSectionHeader(title: "Characters", onSeeMore: () => _navigateToPersonList("Characters", false, characters)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: characters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final edge = characters[index];
                        final node = edge['node'];
                        if (node == null || node['id'] == null) return const SizedBox.shrink();
                        final String uniqueHeroTag = 'person_${widget.mangaId}_${node['id']}';
                        return PersonCard(id: node['id'], name: node['name']['full'] ?? 'Unknown', role: edge['role'] ?? '', imageUrl: node['image']['large'] ?? '', isStaff: false, heroTag: uniqueHeroTag);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                // [Staff Section, etc.]
                if (staff.isNotEmpty) ...[
                  _buildSectionHeader(title: "Staff", onSeeMore: () => _navigateToPersonList("Staff", true, staff)),
                   const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: staff.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final edge = staff[index];
                        final node = edge['node'];
                        if (node == null) return const SizedBox.shrink();
                        final String uniqueHeroTag = 'staff_${widget.mangaId}_${node['id']}';
                        return PersonCard(id: node['id'], name: node['name']['full'] ?? 'Staff', role: (edge['role']?.isEmpty ?? true) ? 'Staff' : edge['role'], imageUrl: node['image']['large'] ?? '', isStaff: true, heroTag: uniqueHeroTag);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 32),
                ],

                const Text("Your Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.grey[100]!, blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                        Row(
                        children: [
                          Text("Score: ${_rating.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Slider(value: _rating, min: 0, max: 10, divisions: 20, activeColor: AppColors.primary, onChanged: (v) => setState(() => _rating = v))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true, value: _readingStatus,
                            items: ['Not Yet', 'Reading', 'Completed', 'On Hold', 'Dropped'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _readingStatus = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(title: const Text("Add to Favorites"), value: _isFavorite, activeColor: AppColors.primary, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _isFavorite = v!)),
                      const SizedBox(height: 10),
                      TextField(controller: _commentController, maxLines: 3, decoration: const InputDecoration(labelText: 'Personal Notes', border: OutlineInputBorder())),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: _saveChanges,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text(_existsInUserList ? 'UPDATE LIST' : 'ADD TO LIST', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (recommendations.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  const Text("You might also like", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: recommendations.length,
                      separatorBuilder: (_,__) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = recommendations[index]['mediaRecommendation'];
                        if (item == null) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MangaDetailsPage(mangaId: item['id'], userId: widget.userId))),
                          child: SizedBox(
                            width: 120,
                            child: Column(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item['coverImage']['large'], fit: BoxFit.cover, width: 120))), const SizedBox(height: 8), Text(item['title']['english'] ?? item['title']['romaji'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // [Keep _buildInfoRow and _buildSectionHeader]
   Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]),
    );
  }

  Widget _buildSectionHeader({required String title, required VoidCallback onSeeMore}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)), InkWell(onTap: onSeeMore, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: Row(children: [Text("See More", style: TextStyle(fontSize: 12, color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.bold)), Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary.withOpacity(0.8))])) )]);
  }
}