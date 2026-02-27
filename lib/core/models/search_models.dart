class SearchResult {
  final int? id;
  final String? stringId;
  final String title;
  final String? coverImage;
  final String status;
  final double? score;
  final String type;
  final int? chapters;

  SearchResult({
    this.id,
    this.stringId,
    required this.title,
    this.coverImage,
    required this.status,
    this.score,
    required this.type,
    this.chapters,
  });

  // Factory for AniList Data
  factory SearchResult.fromAniList(Map<String, dynamic> json) {
    // 1. O(1) Local Variable Extraction
    // Prevents redundant hash lookups and allows safe null-checking
    final Map<String, dynamic>? titleMap = json['title'];
    final Map<String, dynamic>? coverMap = json['coverImage'];

    // 2. Safe Number Parsing
    // APIs sometimes change between int and double. 'num' safely handles both.
    final num? rawScore = json['averageScore'];

    return SearchResult(
      id: json['id'] as int?,
      // 3. Safe Traversal
      // titleMap?['key'] safely short-circuits to null if titleMap is null
      title: titleMap?['display'] ??
          titleMap?['english'] ??
          titleMap?['romaji'] ??
          'Unknown',
      coverImage: coverMap?['large'] as String?,
      status: json['status'] as String? ?? 'Unknown',
      score: rawScore != null ? (rawScore / 10.0) : null,
      type: (json['type'] as String?)?.toLowerCase() ?? 'manga',
      chapters: json['chapters'] as int?,
    );
  }

  // Factory for Firebase User Data
  factory SearchResult.fromFirebase(String id, Map<String, dynamic> data) {
    return SearchResult(
      stringId: id,
      title: data['username'] as String? ?? 'Unknown',
      coverImage: data['avatarUrl'] as String?,
      status: data['bio'] as String? ?? '',
      type: 'user',
    );
  }
}

class FilterOptions {
  String sort;
  String? status;
  List<String> genres;
  List<String> tags;

  FilterOptions({
    this.sort = 'POPULARITY_DESC',
    this.status,
    List<String>? genres,
    List<String>? tags,
  })  : genres = genres ?? [],
        tags = tags ?? [];

  bool get isActive =>
      status != null ||
      genres.isNotEmpty ||
      tags.isNotEmpty ||
      sort != 'POPULARITY_DESC';
}
