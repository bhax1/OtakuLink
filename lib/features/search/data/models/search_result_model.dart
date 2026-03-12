import 'package:otakulink/features/search/domain/entities/search_result_entity.dart';

class SearchResultModel extends SearchResultEntity {
  SearchResultModel({
    super.id,
    super.stringId,
    required super.title,
    super.coverImage,
    required super.status,
    super.score,
    required super.type,
    super.chapters,
  });

  // Factory for AniList Data
  factory SearchResultModel.fromAniList(Map<String, dynamic> json) {
    final Map<String, dynamic>? titleMap = json['title'];
    final Map<String, dynamic>? coverMap = json['coverImage'];

    final num? rawScore = json['averageScore'];

    return SearchResultModel(
      id: json['id'] as int?,
      title:
          titleMap?['display'] ??
          titleMap?['english'] ??
          titleMap?['romaji'] ??
          titleMap?['native'] ??
          'Unknown',

      coverImage: coverMap?['large'] as String?,
      status: json['status'] as String? ?? 'Unknown',
      score: rawScore != null ? (rawScore / 10.0) : null,
      type: (json['type'] as String?)?.toLowerCase() ?? 'manga',
      chapters: json['chapters'] as int?,
    );
  }

  // Factory for Supabase User Data
  factory SearchResultModel.fromSupabase(Map<String, dynamic> data) {
    return SearchResultModel(
      stringId: data['id'] as String?,
      title: data['username'] as String? ?? 'Unknown',
      coverImage: data['avatar_url'] as String?,
      status: (data['is_verified'] as bool? ?? false) ? 'Verified User' : '',
      type: 'user',
    );
  }
}
