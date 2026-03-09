import 'package:otakulink/core/services/reading_history_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/features/manga/domain/entities/user_manga_entity.dart';
import 'package:otakulink/features/manga/data/repositories/supabase_user_manga_repository.dart';
import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';
import 'package:otakulink/features/manga/data/repositories/manga_repository.dart';
import 'package:otakulink/features/manga/utils/manga_details_utils.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

class MangaDetailsState {
  final bool isLoading;
  final bool isSaving;
  final bool existsInUserList;
  final MangaDetailEntity? mangaDetails;
  final String sanitizedDescription;
  final Map? resumePoint;
  final double rating;
  final bool isFavorite;
  final String? status;
  final String comment;

  MangaDetailsState({
    this.isLoading = true,
    this.isSaving = false,
    this.existsInUserList = false,
    this.mangaDetails,
    this.sanitizedDescription = '',
    this.resumePoint,
    this.rating = 0,
    this.isFavorite = false,
    this.status,
    this.comment = '',
  });

  MangaDetailsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? existsInUserList,
    MangaDetailEntity? mangaDetails,
    String? sanitizedDescription,
    Map? resumePoint,
    double? rating,
    bool? isFavorite,
    String? status,
    bool clearStatus = false,
    String? comment,
  }) {
    return MangaDetailsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      existsInUserList: existsInUserList ?? this.existsInUserList,
      mangaDetails: mangaDetails ?? this.mangaDetails,
      sanitizedDescription: sanitizedDescription ?? this.sanitizedDescription,
      resumePoint: resumePoint ?? this.resumePoint,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      status: clearStatus ? null : (status ?? this.status),
      comment: comment ?? this.comment,
    );
  }
}

class MangaDetailsController
    extends AutoDisposeFamilyNotifier<MangaDetailsState, int> {
  // Expose the family argument as 'mangaId' so existing methods don't break
  int get mangaId => arg;

  final SupabaseClient _client = Supabase.instance.client;

  // Tracking Form Diff original points inside the class so the UI is lightweight
  double _origRating = 0;
  bool _origFavorite = false;
  String? _origStatus;
  String _origComment = '';

  String? _remoteLastReadId;
  String? _remoteLastChapterNum;
  int? _remoteLastReadPage;

  @override
  MangaDetailsState build(int arg) {
    Future.microtask(() => loadData());
    return MangaDetailsState();
  }

  Future<void> refreshResumePoint() async {
    final historyService = ref.read(readingHistoryServiceProvider);
    final localPoint = await historyService.getResumePoint(mangaId.toString());

    Map? nextResumePoint;

    // Supabase state (if exists) takes precedence for logged-in users in the UI,
    // but we fall back to local if remote is null.
    if (_remoteLastReadId != null && _remoteLastChapterNum != null) {
      nextResumePoint = {
        'lastReadId': _remoteLastReadId,
        'lastChapterNum': _remoteLastChapterNum,
        'lastReadPage': _remoteLastReadPage,
      };
    } else if (localPoint != null) {
      nextResumePoint = {
        'lastReadId': localPoint['lastReadId'],
        'lastChapterNum': localPoint['lastChapterNum'],
        'lastReadPage': localPoint['lastReadPage'],
      };
    }

    state = state.copyWith(resumePoint: nextResumePoint);
  }

  Future<void> loadData() async {
    final currentUser = _client.auth.currentUser;

    // 1. Always fetch core Manga Details from AniList first
    MangaDetailEntity? apiData;
    String rawDesc = 'No description.';
    try {
      apiData = await ref
          .read(mangaRepositoryProvider)
          .getMangaDetails(mangaId);
      rawDesc = apiData?.description ?? 'No description.';
    } catch (e, stack) {
      SecureLogger.logError("MangaDetailsController LoadAniListData", e, stack);
      state = state.copyWith(isLoading: false);
      return;
    }

    // 2. If guest, just load local history and finish
    if (currentUser == null) {
      final historyService = ref.read(readingHistoryServiceProvider);
      final localPoint = await historyService.getResumePoint(
        mangaId.toString(),
      );

      state = state.copyWith(
        mangaDetails: apiData,
        sanitizedDescription: MangaDetailsUtils.parseHtml(rawDesc),
        isLoading: false,
        resumePoint: localPoint,
      );
      return;
    }

    // 3. For logged-in users, attempt to fetch Supabase data
    try {
      final repo = ref.read(userMangaRepositoryProvider);
      final userEntry = await repo.getUserMangaEntry(currentUser.id, mangaId);

      if (userEntry != null) {
        _origRating = userEntry.rating;
        _origFavorite = userEntry.isFavorite;
        _origStatus = userEntry.status;
        _origComment = userEntry.comment ?? '';

        _remoteLastReadId = userEntry.lastReadId;
        _remoteLastChapterNum = userEntry.lastChapterNum;
        _remoteLastReadPage = userEntry.lastReadPage;

        // Sync remote resume point to local
        final historyService = ref.read(readingHistoryServiceProvider);
        await historyService.syncMangaReadHistory(
          mangaId: mangaId.toString(),
          remoteLastReadId: userEntry.lastReadId,
          remoteLastChapterNum: userEntry.lastChapterNum,
          remoteLastReadPage: userEntry.lastReadPage,
        );

        state = state.copyWith(
          mangaDetails: apiData,
          sanitizedDescription: MangaDetailsUtils.parseHtml(rawDesc),
          existsInUserList: userEntry.status != null,
          rating: _origRating,
          isFavorite: _origFavorite,
          status: _origStatus,
          comment: _origComment,
          isLoading: false,
        );
        await refreshResumePoint();
      } else {
        // Logged in but no entry yet - check if we have local history
        final historyService = ref.read(readingHistoryServiceProvider);
        final localPoint = await historyService.getResumePoint(
          mangaId.toString(),
        );

        state = state.copyWith(
          mangaDetails: apiData,
          sanitizedDescription: MangaDetailsUtils.parseHtml(rawDesc),
          existsInUserList: false,
          isLoading: false,
          resumePoint: localPoint,
        );
      }
    } catch (e, stack) {
      // CRITICAL FIX: If Supabase fails (e.g. table doesn't exist),
      // still show the manga details but log the error.
      SecureLogger.logError("MangaDetailsController LoadUserData", e, stack);

      final historyService = ref.read(readingHistoryServiceProvider);
      final localPoint = await historyService.getResumePoint(
        mangaId.toString(),
      );

      state = state.copyWith(
        mangaDetails: apiData,
        sanitizedDescription: MangaDetailsUtils.parseHtml(rawDesc),
        isLoading: false,
        resumePoint: localPoint,
      );
    }
  }

  void updateForm({
    double? rating,
    bool? isFavorite,
    String? status,
    String? comment,
  }) {
    // Detect changes BEFORE updating state
    final bool statusChanged = status != null && status != state.status;
    final bool ratingChanged = rating != null && rating != state.rating;
    final bool favoriteChanged =
        isFavorite != null && isFavorite != state.isFavorite;
    final bool commentChanged = comment != null && comment != state.comment;

    state = state.copyWith(
      rating: rating,
      isFavorite: isFavorite,
      status: status,
      comment: comment,
    );

    // Auto-save discrete changes (and comment if it changed, though UI usually saves comment manually)
    if (statusChanged || ratingChanged || favoriteChanged || commentChanged) {
      saveChanges();
    }
  }

  Future<void> removeFromLibrary({required bool removeSocial}) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || !state.existsInUserList) return;

    state = state.copyWith(isSaving: true);
    try {
      final repo = ref.read(userMangaRepositoryProvider);

      if (removeSocial) {
        // Full delete
        await repo.deleteEntry(currentUser.id, mangaId);
        state = state.copyWith(
          existsInUserList: false,
          clearStatus: true,
          rating: 0,
          isFavorite: false,
          comment: '',
        );
        _origRating = 0;
        _origFavorite = false;
        _origStatus = null;
        _origComment = '';
        _remoteLastReadId = null;
        _remoteLastChapterNum = null;
        _remoteLastReadPage = null;
      } else {
        // Partial update: Remove progress and status, but keep rating and comment
        // In our current schema, 'status' = null means it's effectively "removed" from active library
        // but the entry remains for the rating/comment.
        // Actually, the user said "Deletes library entry, Deletes reading progress, Keeps rating and commentary"
        // If we delete the row, we lose rating/comment too.
        // So we should UPDATE the row to clear status and progress.
        final rawTitle =
            state.mangaDetails?.manga.titleEnglish ??
            state.mangaDetails?.manga.titleRomaji ??
            state.mangaDetails?.manga.titleDisplay ??
            'Unknown';
        final title = rawTitle.trim().isEmpty ? 'Unknown' : rawTitle;

        final updatedEntry = UserMangaEntry(
          userId: currentUser.id,
          mangaId: mangaId,
          status: null, // Effectively removed
          rating: state.rating,
          isFavorite: false,
          comment: state.comment,
          title: title,
          description: state.sanitizedDescription,
          coverUrl: state.mangaDetails?.manga.coverImageLarge,
          lastReadId: null,
          lastChapterNum: null,
          lastReadPage: 0,
          updatedAt: DateTime.now(),
        );

        await repo.saveEntry(updatedEntry);
        state = state.copyWith(
          existsInUserList: false, // UI should treat it as not in library
          clearStatus: true,
          isFavorite: false,
        );
        _origStatus = null;
        _origFavorite = false;
        _remoteLastReadId = null;
        _remoteLastChapterNum = null;
        _remoteLastReadPage = null;
      }
    } catch (e, stack) {
      SecureLogger.logError(
        "MangaDetailsController RemoveFromLibrary",
        e,
        stack,
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> saveChanges() async {
    if (state.isSaving) return false;

    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return false;

    // Sanitize comment
    final safeComment = MangaDetailsUtils.sanitizeInput(state.comment, 500);

    state = state.copyWith(isSaving: true);

    try {
      final rawTitle =
          state.mangaDetails?.manga.titleEnglish ??
          state.mangaDetails?.manga.titleRomaji ??
          state.mangaDetails?.manga.titleDisplay ??
          'Unknown';
      final title = rawTitle.trim().isEmpty ? 'Unknown' : rawTitle;

      final repo = ref.read(userMangaRepositoryProvider);

      // We preserve the last read info if it exists
      final entry = UserMangaEntry(
        userId: currentUser.id,
        mangaId: mangaId,
        rating: state.rating,
        isFavorite: state.isFavorite,
        status: state.status,
        comment: safeComment,
        title: title,
        description: state.sanitizedDescription,
        coverUrl: state.mangaDetails?.manga.coverImageLarge,
        lastReadId: _remoteLastReadId,
        lastChapterNum: _remoteLastChapterNum,
        lastReadPage: _remoteLastReadPage ?? 0,
        updatedAt: DateTime.now(),
      );

      await repo.saveEntry(entry);

      _origRating = state.rating;
      _origFavorite = state.isFavorite;
      _origStatus = state.status;
      _origComment = safeComment;

      state = state.copyWith(
        existsInUserList: state.status != null,
        isSaving: false,
      );
      return true;
    } catch (e, stack) {
      SecureLogger.logError("MangaDetailsController SaveChanges", e, stack);
      state = state.copyWith(isSaving: false);
      return false;
    }
  }
}

final mangaDetailsControllerProvider = NotifierProvider.autoDispose
    .family<MangaDetailsController, MangaDetailsState, int>(
      MangaDetailsController.new,
    );
