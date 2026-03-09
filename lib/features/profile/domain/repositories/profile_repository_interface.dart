import 'package:otakulink/features/profile/domain/entities/profile_entities.dart';

abstract class ProfileRepositoryInterface {
  String get currentUid;

  Future<ProfileEntity?> getUserProfile();
  Future<ProfileEntity?> getUserProfileById(String uid);

  Future<void> updateUserProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
    required String bannerUrl,
  });

  Future<void> updateTopPicks(List<TopPickEntity> picks);

  Stream<ProfileEntity?> getUserProfileStream(String uid);

  Stream<List<LibraryEntryEntity>> getRecentActivityStream(String uid);

  Stream<List<LibraryEntryEntity>> getLibraryStream({
    required String uid,
    String? status,
    bool favoritesOnly = false,
    String sortBy = 'updatedAt',
    bool ascending = false,
    required int limit,
  });

  Stream<List<LibraryEntryEntity>> getReviewsStream(String uid,
      {required int limit});
}
