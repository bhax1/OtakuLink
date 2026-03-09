class ProfileEntity {
  final String id;
  final String displayName;
  final String username;
  final String bio;
  final String avatarUrl;
  final String bannerUrl;
  final int followerCount;
  final int followingCount;
  final int chaptersRead;
  final int completed;
  final int reading;
  final int dropped;
  final int onHold;
  final int planned;
  final List<String> topGenres;
  final List<TopPickEntity> topPicks;

  ProfileEntity({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.bannerUrl,
    this.followerCount = 0,
    this.followingCount = 0,
    this.chaptersRead = 0,
    this.completed = 0,
    this.reading = 0,
    this.dropped = 0,
    this.onHold = 0,
    this.planned = 0,
    this.topGenres = const [],
    this.topPicks = const [],
  });
}

class TopPickEntity {
  final String mangaId;
  final String title;
  final String coverUrl;

  TopPickEntity({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
  });
}

class LibraryEntryEntity {
  final String id; // usually the mangaId
  final String mangaId;
  final String title;
  final String? imageUrl;
  final double rating;
  final bool isFavorite;
  final String status;
  final double lastChapterRead;
  final String? commentary;
  final DateTime updatedAt;

  LibraryEntryEntity({
    required this.id,
    required this.mangaId,
    required this.title,
    this.imageUrl,
    this.rating = 0.0,
    this.isFavorite = false,
    this.status = 'Reading',
    this.lastChapterRead = 0,
    this.commentary,
    required this.updatedAt,
  });
}
