class MangaEntity {
  final int id;
  final String titleEnglish;
  final String titleRomaji;
  final String titleNative;
  final String titleDisplay;
  final String? coverImageLarge;
  final String? coverImageMedium;
  final String? bannerImage;
  final double? averageScore;
  final String type;
  final String status;
  final String year;
  final List<String> genres;
  final List<String> synonyms;
  final int? chapters;
  final String? exactMangaDexId;

  MangaEntity({
    required this.id,
    required this.titleEnglish,
    required this.titleRomaji,
    required this.titleNative,
    required this.titleDisplay,
    this.coverImageLarge,
    this.coverImageMedium,
    this.bannerImage,
    this.averageScore,
    required this.type,
    required this.status,
    required this.year,
    this.genres = const [],
    this.synonyms = const [],
    this.chapters,
    this.exactMangaDexId,
  });
}

class PersonEntity {
  final int id;
  final String name;
  final String? nativeName;
  final String? image;
  final String? role;
  final String? description;
  final String? age;
  final String? gender;
  final String? bloodType;
  final List<String>? primaryOccupations;
  final String? homeTown;
  final String? yearsActive;

  PersonEntity({
    required this.id,
    required this.name,
    this.nativeName,
    this.image,
    this.role,
    this.description,
    this.age,
    this.gender,
    this.bloodType,
    this.primaryOccupations,
    this.homeTown,
    this.yearsActive,
  });

  PersonEntity copyWith({
    int? id,
    String? name,
    String? nativeName,
    String? image,
    String? role,
    String? description,
    String? age,
    String? gender,
    String? bloodType,
    List<String>? primaryOccupations,
    String? homeTown,
    String? yearsActive,
  }) {
    return PersonEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      image: image ?? this.image,
      role: role ?? this.role,
      description: description ?? this.description,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      primaryOccupations: primaryOccupations ?? this.primaryOccupations,
      homeTown: homeTown ?? this.homeTown,
      yearsActive: yearsActive ?? this.yearsActive,
    );
  }
}

class PaginatedMangaResultEntity {
  final List<MangaEntity> items;
  final bool hasNextPage;
  final int lastPage;
  final int currentPage;

  PaginatedMangaResultEntity({
    required this.items,
    required this.hasNextPage,
    required this.lastPage,
    required this.currentPage,
  });
}

class MangaDetailEntity {
  final MangaEntity manga;
  final String? description;
  final List<PersonEntity> characters;
  final List<PersonEntity> staff;
  final List<MangaEntity> recommendations;

  MangaDetailEntity({
    required this.manga,
    this.description,
    this.characters = const [],
    this.staff = const [],
    this.recommendations = const [],
  });
}
