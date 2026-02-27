import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/feed/feed_services/user_cache.dart';
import 'package:otakulink/pages/feed/news_rail.dart';
import 'package:otakulink/pages/feed/post_card.dart';
import 'package:otakulink/theme.dart';

class FeedPage extends StatefulWidget {
  final Function(int) onTabChange;
  const FeedPage({super.key, required this.onTabChange});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<String> _myFriendsIds = [];

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _handleRefresh() async {
    // 1. Clear the local user metadata cache
    UserCache.clearCache();

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) setState(() {}); // Trigger a rebuild to fetch fresh data
  }

  Future<void> _fetchFriends() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null && data['friends'] != null) {
        if (mounted)
          setState(() => _myFriendsIds = List<String>.from(data['friends']));
      }
    }
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreatePostDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text("Social Feed",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            const SliverToBoxAdapter(child: NewsRail()),
            const SliverToBoxAdapter(child: Divider(height: 24, thickness: 1)),
            FeedStreamSliver(
                friendIds: _myFriendsIds, onTabChange: widget.onTabChange),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

// --- UPDATED: FEED STREAM SLIVER (With Skeleton) ---
class FeedStreamSliver extends StatelessWidget {
  final List<String> friendIds;
  final Function(int) onTabChange;

  const FeedStreamSliver(
      {super.key, required this.friendIds, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feeds')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        // CHANGED: Use Skeleton List here
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FeedSkeletonList();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text("No posts yet."))));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isFriend = friendIds.contains(data['userId']);

              return PostCard(
                  data: data,
                  isFriend: isFriend,
                  postId: doc.id,
                  onTabChange: onTabChange);
            },
            childCount: docs.length,
          ),
        );
      },
    );
  }
}

// --- CREATION DIALOG ---
class CreatePostDialog extends StatefulWidget {
  const CreatePostDialog({super.key});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  bool _isImagePoll = false;
  final List<Map<String, String>> _imageOptions = [];

  // Poll State
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController()
  ];

  // Activity State
  String _selectedActivity = 'Reading';
  final List<String> _activities = [
    'Reading',
    'Watching',
    'Playing',
    'Listening to',
    'Feeling'
  ];

  // Linked Manga State
  Map<String, dynamic>? _linkedManga;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          // Optional: _linkedManga = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    for (var c in _pollOptions) c.dispose();
    super.dispose();
  }

  Future<void> _openMangaSearch() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _MangaSearchPopup(),
    );

    if (result != null && mounted) {
      setState(() {
        _linkedManga = result;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_textController.text.trim().isEmpty &&
        _tabController.index != 1 &&
        _linkedManga == null) return;

    final user = FirebaseAuth.instance.currentUser!;
    final typeIndex = _tabController.index;
    String type = 'normal';
    Map<String, dynamic> extraData = {};

    if (_linkedManga != null) {
      extraData['mangaId'] = _linkedManga!['id'];
      extraData['mangaTitle'] = _linkedManga!['title'];
      extraData['mangaImage'] = _linkedManga!['image'];
    }

    if (typeIndex == 1) {
      // POLL
      type = 'poll';
      extraData['pollType'] = _isImagePoll ? 'image' : 'text';

      if (_isImagePoll) {
        if (_imageOptions.length < 2) return;
        extraData['pollOptions'] = _imageOptions.map((e) => e['text']).toList();
        extraData['pollImages'] = _imageOptions.map((e) => e['image']).toList();
      } else {
        List<String> options = _pollOptions
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        if (options.length < 2) return;
        extraData['pollOptions'] = options;
      }
      extraData['pollVotes'] = {};
    } else if (typeIndex == 2) {
      // Q&A
      type = 'qa';
    } else if (typeIndex == 3) {
      // ACTIVITY
      type = 'activity';
      extraData['activityType'] = _selectedActivity;
    }

    await FirebaseFirestore.instance.collection('feeds').add({
      'userId': user.uid,
      'comment': _textController.text.trim(),
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'replyCount': 0,
      ...extraData,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      title: const Text("Create Post"),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.edit), text: "Post"),
                Tab(icon: Icon(Icons.poll), text: "Poll"),
                Tab(icon: Icon(Icons.help_outline), text: "Q&A"),
                Tab(icon: Icon(Icons.emoji_emotions_outlined), text: "Act."),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 0),
                child: SizedBox(
                  height: 350,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTextInput("What's on your mind?"),
                      _buildWithLinkButton(_buildPollInput()),
                      _buildWithLinkButton(_buildTextInput("Ask something...",
                          bgColor: Colors.red.withOpacity(0.05))),
                      _buildWithLinkButton(_buildActivityInput()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _submitPost,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text("Post", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildWithLinkButton(Widget content) {
    return Column(
      children: [
        Expanded(child: content),
        if (_linkedManga != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: _linkedManga!['image'],
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _linkedManga!['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => setState(() => _linkedManga = null),
                )
              ],
            ),
          ),
        if (_linkedManga == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _openMangaSearch,
              icon: const Icon(Icons.link),
              label: const Text("Link Manga/Manhwa"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextInput(String hint, {Color? bgColor}) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _textController,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPollInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Type: "),
              ToggleButtons(
                isSelected: [!_isImagePoll, _isImagePoll],
                onPressed: (index) => setState(() => _isImagePoll = index == 1),
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 30, minWidth: 80),
                children: const [Text("Text"), Text("Character")],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
                hintText: "Ask a question...", border: UnderlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (!_isImagePoll) ...[
            ...List.generate(_pollOptions.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  controller: _pollOptions[index],
                  decoration: InputDecoration(
                    hintText: "Option ${index + 1}",
                    prefixIcon:
                        const Icon(Icons.radio_button_unchecked, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                if (_pollOptions.length < 9)
                  setState(() => _pollOptions.add(TextEditingController()));
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Option"),
            )
          ] else ...[
            if (_imageOptions.isEmpty)
              const Text("Add at least 2 characters",
                  style: TextStyle(color: Colors.grey)),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_imageOptions.length, (index) {
                final opt = _imageOptions[index];
                return Chip(
                  avatar: CircleAvatar(
                      backgroundImage: NetworkImage(opt['image']!)),
                  label: Text(opt['text']!),
                  onDeleted: () =>
                      setState(() => _imageOptions.removeAt(index)),
                );
              }),
            ),
            const SizedBox(height: 10),
            if (_imageOptions.length < 9)
              OutlinedButton.icon(
                onPressed: () async {
                  final linkedId =
                      _linkedManga != null ? _linkedManga!['id'] : null;

                  final result = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (_) => _CharacterSearchPopup(mangaId: linkedId));

                  if (result != null && mounted) {
                    setState(() => _imageOptions.add(result));
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text("Add Character"),
              ),
          ]
        ],
      ),
    );
  }

  Widget _buildActivityInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedActivity,
            decoration: const InputDecoration(labelText: "I am..."),
            items: _activities
                .map((String val) =>
                    DropdownMenuItem(value: val, child: Text(val)))
                .toList(),
            onChanged: (val) => setState(() => _selectedActivity = val!),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Details (e.g., 'One Piece', 'Happy')...",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER: Mini Search Dialog ---
class _MangaSearchPopup extends StatefulWidget {
  const _MangaSearchPopup();

  @override
  State<_MangaSearchPopup> createState() => _MangaSearchPopupState();
}

class _MangaSearchPopupState extends State<_MangaSearchPopup> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _loading = true);
    const String graphQLQuery = '''
      query (\$search: String) {
        Page(page: 1, perPage: 5) {
          media(search: \$search, type: MANGA, sort: POPULARITY_DESC) {
            id
            title { romaji english }
            coverImage { large }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'query': graphQLQuery,
          'variables': {'search': query}
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _results = data['data']['Page']['media'];
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: "Search Manga...",
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
        ),
        onChanged: _onSearchChanged,
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _loading
            // UPDATED: Nicer loader
            ? Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3))
            : _results.isEmpty
                ? const Center(child: Text("Type to search..."))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final title =
                          item['title']['english'] ?? item['title']['romaji'];
                      final image = item['coverImage']['large'];

                      return ListTile(
                        leading:
                            Image.network(image, width: 40, fit: BoxFit.cover),
                        title: Text(title,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          Navigator.pop(context, {
                            'id': item['id'],
                            'title': title,
                            'image': image,
                          });
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close")),
      ],
    );
  }
}

// --- HELPER: Character Search Dialog ---
class _CharacterSearchPopup extends StatefulWidget {
  final int? mangaId;
  const _CharacterSearchPopup({this.mangaId});

  @override
  State<_CharacterSearchPopup> createState() => _CharacterSearchPopupState();
}

class _CharacterSearchPopupState extends State<_CharacterSearchPopup> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.mangaId != null) {
      _fetchCharactersFromManga(widget.mangaId!);
    }
  }

  Future<void> _fetchCharactersFromManga(int id) async {
    setState(() => _loading = true);
    const String query = '''
      query (\$id: Int) {
        Media(id: \$id) {
          characters(sort: ROLE, perPage: 20) {
            nodes {
              name { full }
              image { large }
            }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'query': query,
          'variables': {'id': id}
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _results = data['data']['Media']['characters']['nodes'];
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performGlobalSearch(query);
      } else if (widget.mangaId != null) {
        _fetchCharactersFromManga(widget.mangaId!);
      }
    });
  }

  Future<void> _performGlobalSearch(String query) async {
    setState(() => _loading = true);
    const String graphQLQuery = '''
      query (\$search: String) {
        Page(page: 1, perPage: 10) {
          characters(search: \$search, sort: FAVOURITES_DESC) {
            name { full }
            image { large }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'query': graphQLQuery,
          'variables': {'search': query}
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _results = data['data']['Page']['characters'];
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            autofocus: widget.mangaId == null,
            decoration: InputDecoration(
              hintText: widget.mangaId != null
                  ? "Filter or search global..."
                  : "Search Character...",
              prefixIcon: const Icon(Icons.person_search),
              border: InputBorder.none,
            ),
            onChanged: _onSearchChanged,
          ),
          if (widget.mangaId != null && _searchCtrl.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Suggestions from linked manga",
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold)),
            )
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _loading
            // UPDATED: Nicer loader
            ? Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3))
            : _results.isEmpty
                ? const Center(child: Text("No characters found"))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final name = item['name']['full'];
                      final image = item['image']['large'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(image),
                          backgroundColor: Colors.grey[200],
                        ),
                        title: Text(name),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: Colors.grey),
                        onTap: () {
                          Navigator.pop(context, <String, String>{
                            'text': name.toString(),
                            'image': image.toString(),
                          });
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close")),
      ],
    );
  }
}

class FeedSkeletonList extends StatelessWidget {
  const FeedSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  SkeletonLoader(width: 40, height: 40, borderRadius: 20),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 120, height: 14),
                      SizedBox(height: 6),
                      SkeletonLoader(width: 80, height: 12),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),
              const SkeletonLoader(width: double.infinity, height: 16),
              const SizedBox(height: 8),
              const SkeletonLoader(width: 200, height: 16),
              const SizedBox(height: 16),
              const SkeletonLoader(width: double.infinity, height: 200),
            ],
          ),
        ),
        childCount: 3,
      ),
    );
  }
}
