class LibraryFilterSettings {
  final String? status;
  final bool favoritesOnly;
  final String sortBy;
  final bool ascending;

  LibraryFilterSettings({
    this.status,
    this.favoritesOnly = false,
    this.sortBy = 'Title',
    this.ascending = true,
  });

  LibraryFilterSettings copyWith({
    String? status,
    bool? favoritesOnly,
    String? sortBy,
    bool? ascending,
  }) {
    return LibraryFilterSettings(
      status: status ?? this.status,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}
