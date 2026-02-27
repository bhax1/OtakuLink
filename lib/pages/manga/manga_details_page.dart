import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core & Services
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/repository/reader_repository.dart';
import 'package:otakulink/services/reading_history_service.dart';

// Widgets
import 'package:otakulink/pages/manga/manga_widgets/person_card.dart';
import 'package:otakulink/pages/manga/manga_details_widgets/chapter_sheet.dart';
import 'package:otakulink/services/user_list_service.dart';
import 'manga_details_widgets/content_section.dart';
import 'manga_details_widgets/manga_header.dart';
import 'manga_details_widgets/manga_info_card.dart';
import 'manga_details_widgets/user_status_editor.dart';

class MangaDetailsPage extends ConsumerStatefulWidget {
  final int mangaId;
  const MangaDetailsPage({super.key, required this.mangaId});

  @override
  ConsumerState<MangaDetailsPage> createState() => _MangaDetailsPageState();
}

class _MangaDetailsPageState extends ConsumerState<MangaDetailsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  bool _isLoading = true;
  bool _isSaving = false;
  bool _existsInUserList = false;
  Map<String, dynamic>? mangaDetails;
  String _sanitizedDescription = '';
  Map? _resumePoint;

  bool _isExpanded = false;

  // Form State
  double _rating = 0;
  bool _isFavorite = false;
  String _status = 'Not Yet';
  final TextEditingController _commentController = TextEditingController();

  // Diff Checking State
  double _origRating = 0;
  bool _origFavorite = false;
  String _origStatus = 'Not Yet';
  String _origComment = '';

  ModalRoute<dynamic>? _route;

  String? _remoteLastReadId;
  String? _remoteLastChapterNum;

  static const int _maxCommentLength = 500;
  static final RegExp _htmlTagRegex =
      RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
  }

  bool get _canUpdateUI {
    if (!mounted) return false;
    if (_route?.animation?.status == AnimationStatus.reverse) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Use microtask to safely read providers on init
    Future.microtask(() => _loadData());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _sanitizeInput(String input, int maxLength) {
    String sanitized = input.trim();
    if (sanitized.length > maxLength) {
      return sanitized.substring(0, maxLength);
    }
    return sanitized;
  }

  bool _isValidSecureUrl(String? url) {
    return url != null && url.isNotEmpty && url.startsWith('https://');
  }

  void _logError(String context, dynamic error) {
    if (kDebugMode) {
      print("SECURITY LOG [$context]: $error");
    }
  }

  void _navigateToPersonList(String pageTitle, bool isStaff, List items) {
    if (!mounted) return;
    context.push(
      '/manga/${widget.mangaId}/persons',
      extra: {
        'title': pageTitle,
        'isStaff': isStaff,
        'initialItems': items,
      },
    );
  }

  // --- MODULAR READ LOGIC ---

  Future<void> _refreshResumePoint() async {
    final historyService = ref.read(readingHistoryServiceProvider);
    var localPoint =
        await historyService.getResumePoint(widget.mangaId.toString());

    if (mounted) {
      setState(() {
        if (localPoint != null && localPoint['lastChapterNum'] != null) {
          _resumePoint = localPoint;
        } else if (_remoteLastReadId != null && _remoteLastChapterNum != null) {
          _resumePoint = {
            'lastReadId': _remoteLastReadId,
            'lastChapterNum': _remoteLastChapterNum,
          };
        } else {
          _resumePoint = null;
        }
      });
    }
  }

  Future<void> _handleMainReadAction() async {
    if (_isLoading) return;

    final title =
        mangaDetails?['title']?['english'] ?? mangaDetails?['title']?['romaji'];
    final cover = mangaDetails?['coverImage']?['large'];
    final safeCover = _isValidSecureUrl(cover) ? cover : '';

    if (title == null || title.toString().trim().isEmpty) {
      _showDialog("Unavailable", "Manga title is missing or invalid.");
      return;
    }

    bool isDialogShowing = true;
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => isDialogShowing = false);

    try {
      final readerRepo = ref.read(readerRepositoryProvider);
      final chapters = await readerRepo.fetchChapters(title);

      if (!mounted) return;
      if (isDialogShowing) navigator.pop();

      if (chapters.isEmpty) {
        _showDialog("No Chapters", "No chapters found for this manga yet.");
        return;
      }

      int targetIndex = 0;

      if (_resumePoint != null) {
        final targetId = _resumePoint!['lastReadId'].toString();
        targetIndex =
            chapters.indexWhere((ch) => ch['id'].toString() == targetId);

        if (targetIndex == -1) targetIndex = chapters.length - 1;
      } else {
        double minChapterNum = double.infinity;
        targetIndex = chapters.length - 1;

        for (int i = 0; i < chapters.length; i++) {
          final chStr = chapters[i]['chapter'];
          if (chStr != null && chStr.toString().isNotEmpty) {
            final double? chNum = double.tryParse(chStr.toString());
            if (chNum != null && chNum >= 0 && chNum < minChapterNum) {
              minChapterNum = chNum;
              targetIndex = i;
            }
          }
        }
      }

      await context.push('/reader', extra: {
        'initialChapterIndex': targetIndex,
        'allChapters': chapters,
        'mangaId': widget.mangaId.toString(),
        'mangaTitle': title,
        'mangaCover': safeCover,
      });

      await _refreshResumePoint();
    } catch (e) {
      if (!mounted) return;
      if (isDialogShowing) navigator.pop();
      _logError("HandleMainAction", e);
      _showDialog("Error", "Unable to load chapter. Please try again.");
    }
  }

  Future<void> _handleOpenChapters() async {
    if (_isLoading) return;

    final title =
        mangaDetails?['title']?['english'] ?? mangaDetails?['title']?['romaji'];
    if (title == null || title.toString().trim().isEmpty) return;

    bool isDialogShowing = true;
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => isDialogShowing = false);

    try {
      final readerRepo = ref.read(readerRepositoryProvider);
      final chapters = await readerRepo.fetchChapters(title);

      if (!mounted) return;
      if (isDialogShowing) navigator.pop();

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        isScrollControlled: true,
        builder: (_) => ChapterSheet(
          chapters: chapters,
          onChapterTap: (index) async {
            final cover = mangaDetails?['coverImage']?['large'];
            final safeCover = _isValidSecureUrl(cover) ? cover : '';

            Navigator.pop(context);

            await context.push('/reader', extra: {
              'initialChapterIndex': index,
              'allChapters': chapters,
              'mangaId': widget.mangaId.toString(),
              'mangaTitle': title,
              'mangaCover': safeCover,
            });

            await _refreshResumePoint();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (isDialogShowing) navigator.pop();
      _logError("FetchChapters", e);
      _showDialog("Error", "Unable to load chapters. Please try again later.");
    }
  }

  // --- DATA LOADING ---

  Future<void> _loadData() async {
    final currentUser = _auth.currentUser;
    await _refreshResumePoint();

    if (currentUser == null) {
      try {
        final apiData = await AniListService.getMangaDetails(widget.mangaId);
        final rawDesc = apiData?['description'] ?? 'No description.';

        if (_canUpdateUI) {
          setState(() {
            mangaDetails = apiData;
            _sanitizedDescription = _parseHtml(rawDesc);
            _isLoading = false;
          });
        }
      } catch (e) {
        _logError("LoadGuestData", e);
        if (_canUpdateUI) setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final dbService = ref.read(userListServiceProvider);

      final results = await Future.wait([
        AniListService.getMangaDetails(widget.mangaId),
        dbService.getUserMangaEntry(currentUser.uid, widget.mangaId),
      ]);

      final apiData = results[0] as Map<String, dynamic>?;
      final userDoc = results[1] as dynamic;
      final rawDesc = apiData?['description'] ?? 'No description.';

      if (mounted) {
        setState(() {
          mangaDetails = apiData;
          _sanitizedDescription = _parseHtml(rawDesc);

          if (userDoc.exists) {
            _existsInUserList = true;
            final data = userDoc.data() as Map<String, dynamic>;

            _rating = double.tryParse(data['rating'].toString()) ?? 0.0;
            _isFavorite = data['isFavorite'] ?? false;
            _status = data['status'] ?? 'Not Yet';
            _commentController.text = data['comment'] ?? '';

            _remoteLastReadId = data['lastReadId']?.toString();
            _remoteLastChapterNum = data['lastChapterNum']?.toString();

            final List<dynamic> rawReadChapters = data['readChapters'] ?? [];
            final List<String> readChapters =
                rawReadChapters.map((e) => e.toString()).toList();

            if (readChapters.isNotEmpty) {
              final historyService = ref.read(readingHistoryServiceProvider);

              historyService
                  .syncMangaReadHistory(
                mangaId: widget.mangaId.toString(),
                readChapterIds: readChapters,
                remoteLastReadId: _remoteLastReadId,
                remoteLastChapterNum: _remoteLastChapterNum,
              )
                  .then((_) {
                if (mounted) _refreshResumePoint();
              });
            } else {
              _refreshResumePoint();
            }

            _origRating = _rating;
            _origFavorite = _isFavorite;
            _origStatus = _status;
            _origComment = _commentController.text;
          } else {
            _resetForm();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      _logError("LoadUserData", e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _existsInUserList = false;
    _rating = 0;
    _isFavorite = false;
    _status = 'Not Yet';
    _commentController.clear();
  }

  // --- DATA SAVING ---

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showDialog("Login Required", "Please login to save your list.");
      return;
    }

    if (_existsInUserList) {
      if (_rating == _origRating &&
          _isFavorite == _origFavorite &&
          _status == _origStatus &&
          _commentController.text == _origComment) {
        return;
      }
    }

    final safeComment =
        _sanitizeInput(_commentController.text, _maxCommentLength);
    setState(() => _isSaving = true);

    try {
      final title = mangaDetails?['title']?['english'] ??
          mangaDetails?['title']?['romaji'] ??
          'Unknown';

      final dbService = ref.read(userListServiceProvider);

      await dbService.saveEntry(
        userId: currentUser.uid,
        mangaId: widget.mangaId,
        rating: _rating,
        isFavorite: _isFavorite,
        status: _status,
        comment: safeComment,
        title: title,
        imageUrl: mangaDetails?['coverImage']?['large'],
      );

      if (mounted) {
        setState(() {
          _origRating = _rating;
          _origFavorite = _isFavorite;
          _origStatus = _status;
          _origComment = safeComment;
          _commentController.text = safeComment;
          _existsInUserList = true;
        });
        _showDialog('Success', 'Library updated successfully!');
      }
    } catch (e) {
      _logError("SaveChanges", e);
      if (mounted) _showDialog('Error', 'Failed to save changes.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  static String _parseHtml(String htmlString) {
    if (htmlString.isEmpty) return "";
    String result = htmlString.replaceAll(_htmlTagRegex, '');
    result = result
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('<br>', '\n');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: _isLoading ? _buildSkeleton() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (mangaDetails == null) {
      return const Center(child: Text("Manga not found"));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final m = mangaDetails!;

    final title = m['title']?['english'] ?? m['title']?['romaji'] ?? 'Unknown';
    final cover = m['coverImage']?['extraLarge'] ?? m['coverImage']?['large'];
    final banner = m['bannerImage'];
    final characters = (m['characters']?['edges'] as List?) ?? [];
    final staff = (m['staff']?['edges'] as List?) ?? [];
    final recommendations = (m['recommendations']?['nodes'] as List?) ?? [];
    final safeCover = _isValidSecureUrl(cover) ? cover : null;
    final currentUser = _auth.currentUser;

    final String publicationStatus = m['status'] ?? 'UNKNOWN';

    return CustomScrollView(
      key: const ValueKey('Content'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        MangaHeader(
          title: title,
          coverUrl: safeCover,
          bannerUrl: _isValidSecureUrl(banner) ? banner : null,
          genres: m['genres'] ?? [],
          mangaId: widget.mangaId,
          isLoggedIn: currentUser != null,
          existsInList: _existsInUserList,
          onCommentsPressed: () {
            if (currentUser != null) {
              context.push(
                '/manga/${widget.mangaId}/discussion',
                extra: {
                  'mangaId': widget.mangaId,
                  'userId': currentUser.uid,
                  'mangaName': title,
                },
              );
            }
          },
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MangaInfoCard(details: m),
                const SizedBox(height: 32),

                // --- DYNAMIC BUTTONS ---
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: Icon(_resumePoint == null
                            ? Icons.play_arrow
                            : Icons.menu_book),
                        label: Text(
                          _resumePoint == null
                              ? 'START READING'
                              : 'CONTINUE CH ${_resumePoint!['lastChapterNum']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _handleMainReadAction,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.secondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _handleOpenChapters,
                        child: Icon(
                          Icons.list,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                // ---------------------------

                const SizedBox(height: 32),
                Text(
                  "Synopsis",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      child: Text(
                        _sanitizedDescription,
                        maxLines: _isExpanded ? null : 4,
                        overflow: _isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 16),
                        child: Column(
                          children: [
                            Text(
                              _isExpanded ? "Collapse" : "Read More",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? theme.colorScheme.onSurface
                                        .withOpacity(0.7)
                                    : theme.colorScheme.primary
                                        .withOpacity(0.7),
                              ),
                            ),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: theme.colorScheme.secondary,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                ),
                const SizedBox(height: 20),

                ContentSection(
                  title: "Your Status",
                  child: UserStatusEditor(
                    rating: _rating,
                    status: _status,
                    isFavorite: _isFavorite,
                    isSaving: _isSaving,
                    existsInList: _existsInUserList,
                    mangaStatus: publicationStatus,
                    commentController: _commentController,
                    onRatingChanged: (v) => setState(() => _rating = v),
                    onStatusChanged: (v) => setState(() => _status = v!),
                    onFavoriteChanged: (v) => setState(() => _isFavorite = v!),
                    onSave: _saveChanges,
                  ),
                ),
                if (characters.isNotEmpty)
                  ContentSection(
                    title: "Characters",
                    onSeeMore: () =>
                        _navigateToPersonList("Characters", false, characters),
                    child: SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: characters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _buildCharacterItem(characters[i]),
                      ),
                    ),
                  ),
                if (staff.isNotEmpty)
                  ContentSection(
                    title: "Staff",
                    onSeeMore: () =>
                        _navigateToPersonList("Staff", true, staff),
                    child: SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: staff.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _buildStaffItem(staff[i]),
                      ),
                    ),
                  ),
                if (recommendations.isNotEmpty)
                  ContentSection(
                    title: "You might also like",
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recommendations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _buildRecommendationItem(recommendations[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterItem(dynamic edge) {
    final node = edge['node'];
    if (node == null) return const SizedBox.shrink();
    return PersonCard(
      id: node['id'],
      name: node['name']['full'] ?? 'Unknown',
      role: edge['role'] ?? '',
      imageUrl: node['image']['large'] ?? '',
      isStaff: false,
      heroTag: 'person_${widget.mangaId}_${node['id']}',
    );
  }

  Widget _buildStaffItem(dynamic edge) {
    final node = edge['node'];
    if (node == null) return const SizedBox.shrink();
    return PersonCard(
      id: node['id'],
      name: node['name']['full'] ?? 'Staff',
      role: edge['role'] ?? 'Staff',
      imageUrl: node['image']['large'] ?? '',
      isStaff: true,
      heroTag: 'staff_${widget.mangaId}_${node['id']}',
    );
  }

  Widget _buildRecommendationItem(dynamic rec) {
    final item = rec['mediaRecommendation'];
    if (item == null) return const SizedBox.shrink();
    final recCover = item['coverImage']?['large'];

    return GestureDetector(
      onTap: () => context.push('/manga/${item['id']}'),
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            Expanded(
              child: (recCover != null && recCover.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: recCover,
                      memCacheHeight: 250,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              item['title']['english'] ?? item['title']['romaji'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return CustomScrollView(
      key: const ValueKey('Skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ],
    );
  }
}
