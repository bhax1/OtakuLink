class TopPickItem {
  final String mangaId;
  final String title;
  final String coverUrl;

  TopPickItem({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
  });

  factory TopPickItem.fromMap(Map<String, dynamic> data) {
    return TopPickItem(
      mangaId: data['mangaId'] ?? '',
      title: data['title'] ?? 'Unknown',
      coverUrl: data['coverUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'title': title,
      'coverUrl': coverUrl,
    };
  }
}

class UserModel {
  final String id;
  final String displayName;
  final String username;
  final String bio;
  final String avatarUrl;
  final String bannerUrl;

  // Social Stats
  final int followerCount;
  final int followingCount;

  // Manga Stats
  final int chaptersRead;
  final int completed;
  final int reading;
  final int dropped;
  final int onHold;
  final int planned;

  final List<String> topGenres;
  final List<TopPickItem> topPicks;
  final Map<String, dynamic> rawStats;

  UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.bannerUrl,
    this.followerCount = 0, // <-- ADDED
    this.followingCount = 0, // <-- ADDED
    this.chaptersRead = 0,
    this.completed = 0,
    this.reading = 0,
    this.dropped = 0,
    this.onHold = 0,
    this.planned = 0,
    this.topGenres = const [],
    this.topPicks = const [],
    this.rawStats = const {},
  });

  UserModel copyWith({
    String? id,
    String? displayName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    int? followerCount,
    int? followingCount,
    int? chaptersRead,
    int? completed,
    int? reading,
    int? dropped,
    int? onHold,
    int? planned,
    List<String>? topGenres,
    List<TopPickItem>? topPicks,
    Map<String, dynamic>? rawStats,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      chaptersRead: chaptersRead ?? this.chaptersRead,
      completed: completed ?? this.completed,
      reading: reading ?? this.reading,
      dropped: dropped ?? this.dropped,
      onHold: onHold ?? this.onHold,
      planned: planned ?? this.planned,
      topGenres: topGenres ?? this.topGenres,
      topPicks: topPicks ?? this.topPicks,
      rawStats: rawStats ?? this.rawStats,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    final stats = data['stats'] as Map<String, dynamic>? ?? {};

    return UserModel(
      id: uid,
      displayName: data['displayName'] ?? '',
      username: data['username'] ?? '',
      bio: data['bio'] ?? '',
      avatarUrl: data['avatarUrl'] ??
          "https://cdn.vectorstock.com/i/500p/17/16/default-avatar-anime-girl-profile-icon-vector-21171716.jpg",
      bannerUrl: data['bannerUrl'] ??
          "https://i.pinimg.com/736x/84/03/9b/84039b50064a385edf33b3256daee23a.jpg",

      // Parse Social Stats from the root of the document
      followerCount: data['followerCount']?.toInt() ?? 0,
      followingCount: data['followingCount']?.toInt() ?? 0,

      // Parse Manga Stats from the 'stats' map
      chaptersRead: stats['chaptersRead'] ?? 0,
      completed: stats['completed'] ?? 0,
      reading: stats['reading'] ?? 0,
      dropped: stats['dropped'] ?? 0,
      onHold: stats['onHold'] ?? 0,
      planned: stats['planned'] ?? 0,

      topGenres: List<String>.from(data['topGenres'] ?? []),

      topPicks: (data['topPicks'] as List<dynamic>?)
              ?.map((item) => TopPickItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
