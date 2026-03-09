class SearchFilterOptions {
  final String sort;
  final String? status;
  final List<String> genres;
  final List<String> tags;

  SearchFilterOptions({
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

  SearchFilterOptions copyWith({
    String? sort,
    String? status,
    List<String>? genres,
    List<String>? tags,
  }) {
    return SearchFilterOptions(
      sort: sort ?? this.sort,
      status: status ?? this.status,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
    );
  }
}
