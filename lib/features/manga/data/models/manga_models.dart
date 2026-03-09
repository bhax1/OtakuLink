import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';

class MangaModel extends MangaEntity {
  MangaModel({
    required super.id,
    required super.titleEnglish,
    required super.titleRomaji,
    required super.titleDisplay,
    super.coverImageLarge,
    super.coverImageMedium,
    super.bannerImage,
    super.averageScore,
    required super.type,
    required super.status,
    required super.year,
    super.genres,
    super.chapters,
    super.exactMangaDexId,
  });

  factory MangaModel.fromAniList(Map<String, dynamic> json) {
    final titleMap = json['title'] as Map<String, dynamic>?;
    final coverMap = json['coverImage'] as Map<String, dynamic>?;

    // Check if it's the simplified format from recommendations or standard list
    String? coverLarge;
    String? coverMedium;
    if (coverMap != null && coverMap.containsKey('large')) {
      coverLarge = coverMap['large'] as String?;
      coverMedium = coverMap['medium'] as String?;
    } else if (json['coverImage'] is String) {
      coverLarge = json['coverImage'] as String?;
    }

    final rawScore = json['averageScore'];
    double? parsedScore;
    if (rawScore is int) {
      parsedScore = rawScore / 10.0;
    } else if (rawScore is num) {
      parsedScore = rawScore / 10.0;
    }

    final startDateMap = json['startDate'] as Map<String, dynamic>?;
    String yearString = '-';
    if (startDateMap != null && startDateMap['year'] != null) {
      yearString = startDateMap['year'].toString();
    } else if (json['year'] != null) {
      yearString = json['year'].toString();
    }

    return MangaModel(
      id: json['id'] as int,
      titleEnglish: titleMap?['english']?.toString() ?? 'Unknown',
      titleRomaji: titleMap?['romaji']?.toString() ?? 'Unknown',
      titleDisplay:
          titleMap?['display']?.toString() ??
          titleMap?['english']?.toString() ??
          titleMap?['romaji']?.toString() ??
          'Unknown',
      coverImageLarge: coverLarge,
      coverImageMedium: coverMedium,
      bannerImage: json['bannerImage']?.toString(),
      averageScore: parsedScore,
      type: json['type']?.toString() ?? 'Manga',
      status: json['status']?.toString() ?? 'Unknown',
      year: yearString,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      chapters: json['chapters'] as int?,
      exactMangaDexId: json['exactMangaDexId']?.toString(),
    );
  }
}

class PersonModel extends PersonEntity {
  PersonModel({
    required super.id,
    required super.name,
    super.nativeName,
    super.image,
    super.role,
    super.description,
    super.age,
    super.gender,
    super.bloodType,
    super.primaryOccupations,
    super.homeTown,
    super.yearsActive,
  });

  factory PersonModel.fromAniListCharacter(Map<String, dynamic> json) {
    final nameMap = json['name'] as Map<String, dynamic>?;
    final imageMap = json['image'] as Map<String, dynamic>?;

    return PersonModel(
      id: json['id'] as int,
      name: nameMap?['full']?.toString() ?? 'Unknown',
      nativeName: nameMap?['native']?.toString(),
      image: imageMap?['large']?.toString() ?? imageMap?['medium']?.toString(),
      role: json['role']?.toString(),
      description: json['description']?.toString(),
      age: json['age']?.toString(),
      gender: json['gender']?.toString(),
      bloodType: json['bloodType']?.toString(),
    );
  }

  factory PersonModel.fromAniListStaff(Map<String, dynamic> json) {
    final nameMap = json['name'] as Map<String, dynamic>?;
    final imageMap = json['image'] as Map<String, dynamic>?;

    return PersonModel(
      id: json['id'] as int,
      name: nameMap?['full']?.toString() ?? 'Unknown',
      nativeName: nameMap?['native']?.toString(),
      image: imageMap?['large']?.toString() ?? imageMap?['medium']?.toString(),
      role:
          json['primaryOccupations'] != null &&
              (json['primaryOccupations'] as List).isNotEmpty
          ? (json['primaryOccupations'] as List).first.toString()
          : null,
      description: json['description']?.toString(),
      primaryOccupations: (json['primaryOccupations'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      homeTown: json['homeTown']?.toString(),
      yearsActive: (json['yearsActive'] as List?)
          ?.map((e) => e.toString())
          .join(' - '),
    );
  }

  @override
  PersonModel copyWith({
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
    return PersonModel(
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
