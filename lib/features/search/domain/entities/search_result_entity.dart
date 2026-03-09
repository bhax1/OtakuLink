class SearchResultEntity {
  final int? id; // for AniList
  final String? stringId; // for Firebase user
  final String title;
  final String? coverImage;
  final String status;
  final double? score;
  final String type; // 'manga', 'user', etc.
  final int? chapters;

  SearchResultEntity({
    this.id,
    this.stringId,
    required this.title,
    this.coverImage,
    required this.status,
    this.score,
    required this.type,
    this.chapters,
  });
}
