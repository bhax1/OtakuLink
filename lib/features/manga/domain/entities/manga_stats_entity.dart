class MangaStatsEntity {
  final int mangaId;
  final int bookmarkCount;
  final double ratingSum;
  final int ratingCount;
  final double averageRating;
  final DateTime updatedAt;

  const MangaStatsEntity({
    required this.mangaId,
    this.bookmarkCount = 0,
    this.ratingSum = 0.0,
    this.ratingCount = 0,
    this.averageRating = 0.0,
    required this.updatedAt,
  });

  factory MangaStatsEntity.fromJson(Map<String, dynamic> json) {
    return MangaStatsEntity(
      mangaId: json['manga_id'] as int,
      bookmarkCount: json['bookmark_count'] as int? ?? 0,
      ratingSum: (json['rating_sum'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manga_id': mangaId,
      'bookmark_count': bookmarkCount,
      'rating_sum': ratingSum,
      'rating_count': ratingCount,
      'average_rating': averageRating,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MangaStatsEntity copyWith({
    int? mangaId,
    int? bookmarkCount,
    double? ratingSum,
    int? ratingCount,
    double? averageRating,
    DateTime? updatedAt,
  }) {
    return MangaStatsEntity(
      mangaId: mangaId ?? this.mangaId,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      ratingSum: ratingSum ?? this.ratingSum,
      ratingCount: ratingCount ?? this.ratingCount,
      averageRating: averageRating ?? this.averageRating,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
