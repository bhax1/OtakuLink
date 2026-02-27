class AniListQueries {
  // --- LIST QUERIES (Require $isAdult) ---

  static const String queryTrendingCarousel = '''
    query (\$isAdult: Boolean) {
      Page(page: 1, perPage: 10) {
        media(sort: TRENDING_DESC, type: MANGA, isAdult: \$isAdult) {
          id
          title { romaji english }
          coverImage { extraLarge large medium color }
          bannerImage
          averageScore
          status
          type
          startDate { year }
          description
          genres
        }
      }
    }
  ''';

  static const String queryNewReleases = '''
    query (\$year: FuzzyDateInt, \$isAdult: Boolean) {
      Page(page: 1, perPage: 15) {
        media(sort: POPULARITY_DESC, type: MANGA, status: RELEASING, startDate_greater: \$year, isAdult: \$isAdult) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryTrendingList = '''
    query (\$isAdult: Boolean) {
      Page(page: 2, perPage: 15) { 
        media(sort: TRENDING_DESC, type: MANGA, isAdult: \$isAdult) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryHallOfFame = '''
    query (\$isAdult: Boolean) {
      Page(page: 1, perPage: 15) {
        media(sort: SCORE_DESC, type: MANGA, averageScore_greater: 88, isAdult: \$isAdult) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryFanFavorites = '''
    query (\$isAdult: Boolean) {
      Page(page: 1, perPage: 15) {
        media(sort: FAVOURITES_DESC, type: MANGA, isAdult: \$isAdult) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryManhwa = '''
    query (\$isAdult: Boolean) {
      Page(page: 1, perPage: 15) {
        media(sort: TRENDING_DESC, type: MANGA, countryOfOrigin: "KR", isAdult: \$isAdult) {
          id
          title { romaji english }
          coverImage { large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String queryPaginatedManga = '''
    query (\$page: Int, \$sort: [MediaSort], \$status: MediaStatus, \$country: CountryCode, \$year: FuzzyDateInt, \$minScore: Int, \$isAdult: Boolean) {
      Page(page: \$page, perPage: 20) {
        pageInfo { currentPage lastPage hasNextPage }
        media(
          sort: \$sort, 
          status: \$status, 
          countryOfOrigin: \$country, 
          startDate_greater: \$year, 
          averageScore_greater: \$minScore,
          type: MANGA, 
          isAdult: \$isAdult
        ) {
          id
          title { romaji english }
          coverImage { extraLarge large medium color }
          averageScore
          status
          type
          startDate { year }
        }
      }
    }
  ''';

  static const String search = '''
    query (\$search: String, \$sort: [MediaSort], \$status: MediaStatus, \$genres: [String], \$tags: [String], \$format: MediaFormat, \$country: CountryCode, \$isAdult: Boolean) {
      Page(page: 1, perPage: 12) {
        media(
          search: \$search, 
          sort: \$sort, 
          status: \$status, 
          genre_in: \$genres, 
          tag_in: \$tags, 
          format: \$format, 
          countryOfOrigin: \$country, 
          type: MANGA, 
          isAdult: \$isAdult
        ) {
          id
          title { romaji english }
          coverImage { extraLarge large medium color }
          bannerImage
          averageScore
          status
          type
          startDate { year }
          genres
          chapters
        }
      }
    }
  ''';

  // --- ENTITY QUERIES (Do NOT use $isAdult) ---

  static const String queryRecommendations = '''
    query (\$id: Int) {
      Media(id: \$id, type: MANGA) {
        title { romaji english }
        recommendations(perPage: 10, sort: RATING_DESC) {
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { large medium color }
              averageScore
              status
              type
              startDate { year }
            }
          }
        }
      }
    }
  ''';

  static const String queryMangaDetails = '''
    query (\$id: Int) {
      Media (id: \$id, type: MANGA) {
        id
        title { romaji english native }
        synonyms
        coverImage { extraLarge large medium color }
        bannerImage
        description
        status
        genres
        averageScore
        chapters
        volumes
        countryOfOrigin
        startDate { year month day }
        externalLinks { site url }
        characters (sort: ROLE, perPage: 10) {
          edges { 
            role 
            node { 
              id
              name { full } 
              image { large medium } 
            } 
          }
        }
        staff (sort: RELEVANCE, perPage: 5) {
          edges { 
            role 
            node { 
              id
              name { full } 
              image { large medium } 
            } 
          }
        }
        recommendations (sort: RATING_DESC, perPage: 10) {
          nodes { 
            mediaRecommendation { 
              id 
              title { romaji english } 
              coverImage { large medium color } 
            } 
          }
        }
      }
    }
  ''';

  static const String queryStaffDetails = '''
    query (\$id: Int) {
      Staff(id: \$id) {
        name { full native }
        image { large medium }
        description
        primaryOccupations
        homeTown
        yearsActive
      }
    }
  ''';

  static const String queryCharacterDetails = '''
    query (\$id: Int) {
      Character(id: \$id) {
        name { full native }
        image { large medium }
        description
        gender
        age
        bloodType
      }
    }
  ''';

  static const String queryAllCharacters = '''
    query (\$id: Int, \$page: Int) {
      Media(id: \$id, type: MANGA) {
        characters(page: \$page, perPage: 25, sort: ROLE) {
          pageInfo { hasNextPage currentPage }
          edges {
            role
            node { id name { full } image { large } }
          }
        }
      }
    }
  ''';

  static const String queryAllStaff = '''
    query (\$id: Int, \$page: Int) {
      Media(id: \$id, type: MANGA) {
        staff(page: \$page, perPage: 25, sort: RELEVANCE) {
          pageInfo { hasNextPage currentPage }
          edges {
            role
            node { id name { full } image { large } }
          }
        }
      }
    }
  ''';

  static const String queryPaginatedRecommendations = '''
    query (\$id: Int, \$page: Int) {
      Media(id: \$id, type: MANGA) {
        recommendations(page: \$page, perPage: 20, sort: RATING_DESC) {
          pageInfo { currentPage lastPage hasNextPage }
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { extraLarge large medium color }
              averageScore
              status
              type
              startDate { year }
            }
          }
        }
      }
    }
  ''';

  static const String getGenresAndTags = '''
    query {
      GenreCollection
      MediaTagCollection {
        name
        isAdult
        category
      }
    }
  ''';
}
