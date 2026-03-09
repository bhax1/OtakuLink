import 'package:otakulink/features/manga/domain/entities/user_manga_entity.dart';

abstract class UserMangaRepositoryInterface {
  Future<UserMangaEntry?> getUserMangaEntry(String userId, int mangaId);
  Future<void> saveEntry(UserMangaEntry entry);
  Future<List<UserMangaEntry>> getUserLibrary(String userId);
  Future<void> deleteEntry(String userId, int mangaId);
}
