class UserMangaEntry {
  final String userId;
  final int mangaId;
  final String? status;
  final double rating;
  final bool isFavorite;
  final String? comment;
  final String? lastReadId;
  final String? lastChapterNum;
  final int lastReadPage;
  final String? title;
  final String? coverUrl;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final String? description;

  UserMangaEntry({
    required this.userId,
    required this.mangaId,
    this.status,
    this.rating = 0.0,
    this.isFavorite = false,
    this.comment,
    this.lastReadId,
    this.lastChapterNum,
    this.lastReadPage = 0,
    this.title,
    this.coverUrl,
    this.description,
    this.updatedAt,
    this.createdAt,
  });

  factory UserMangaEntry.fromJson(Map<String, dynamic> json) {
    // Handle joined manga metadata (Supabase joins can return Map or List)
    Map<String, dynamic>? mangaData;
    final rawMangas = json['mangas'];
    if (rawMangas is Map) {
      mangaData = Map<String, dynamic>.from(rawMangas);
    } else if (rawMangas is List && rawMangas.isNotEmpty) {
      mangaData = Map<String, dynamic>.from(rawMangas[0]);
    }

    return UserMangaEntry(
      userId: json['user_id'] as String,
      mangaId: json['manga_id'] as int,
      status: json['status'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      isFavorite: json['is_favorite'] as bool? ?? false,
      comment: json['comment'] as String?,
      lastReadId: json['last_read_id'] as String?,
      lastChapterNum: json['last_chapter_num'] as String?,
      lastReadPage: json['last_read_page'] as int? ?? 0,
      title: (mangaData?['title'] ?? json['title']) as String?,
      coverUrl:
          (mangaData?['cover_url'] ?? json['image_url'] ?? json['cover_url'])
              as String?,
      description:
          (mangaData?['description'] ?? json['description']) as String?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'manga_id': mangaId,
    'status': status,
    'rating': rating,
    'is_favorite': isFavorite,
    // 'comment' is handled separately via notes table
    'last_read_id': lastReadId,
    'last_chapter_num': lastChapterNum,
    'last_read_page': lastReadPage,
    'updated_at': updatedAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
  };

  /// Returns data for the 'mangas' metadata table
  Map<String, dynamic> toMangaJson() => {
    'id': mangaId,
    'title': title,
    'cover_url': coverUrl,
    'description': description,
    'updated_at': DateTime.now().toIso8601String(),
  };
}
