import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import '../../domain/entities/discussion_entities.dart';
import '../../data/repositories/discussion_repository.dart';

class DiscussionState {
  final bool isLoading;
  final bool isSending;
  final List<DiscussionComment> comments;
  final int totalCount;
  final String? errorMessage;
  final int currentPage;

  DiscussionState({
    this.isLoading = false,
    this.isSending = false,
    this.comments = const [],
    this.totalCount = 0,
    this.errorMessage,
    this.currentPage = 1,
  });

  DiscussionState copyWith({
    bool? isLoading,
    bool? isSending,
    List<DiscussionComment>? comments,
    int? totalCount,
    String? errorMessage,
    int? currentPage,
  }) {
    return DiscussionState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      comments: comments ?? this.comments,
      totalCount: totalCount ?? this.totalCount,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

typedef DiscussionArgs = ({int mangaId, String? chapterId});

class DiscussionController
    extends FamilyNotifier<DiscussionState, DiscussionArgs> {
  int get mangaId => arg.mangaId;
  String? get chapterId => arg.chapterId;

  RealtimeChannel? _subscription;

  @override
  DiscussionState build(DiscussionArgs arg) {
    Future.microtask(() => loadComments());
    _setupRealtimeSubscription();

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    return DiscussionState(isLoading: true);
  }

  void _setupRealtimeSubscription() {
    _subscription = Supabase.instance.client
        .channel('public:discussions:manga_$mangaId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'discussions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'manga_id',
            value: mangaId,
          ),
          callback: (payload) {
            final json = payload.newRecord;
            if (json.isEmpty) return;

            // Local sanity check to match chapter context
            final recordChapterId = json['chapter_id'];
            if (chapterId != null && recordChapterId != chapterId) return;
            if (chapterId == null && recordChapterId != null) return;

            // Append new comment to the top asynchronously to fetch profile
            // If it's the current user, we just wait for `loadComments(page: 1)`
            // which is triggered in `postComment`.
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;
            if (json['user_id'] != currentUserId) {
              // Rather than building the complex object here manually without relations,
              // just trigger a silent background refresh of page 1.
              loadComments(page: 1, silentRealtimeRefresh: true);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'discussion_reactions',
          callback: (payload) {
            final json = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;

            if (json.isEmpty) return;

            final discussionId = json['discussion_id'];
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;

            // Check if the reaction is for a comment in our active view
            final belongsToActiveComment = state.comments.any(
              (c) => c.id == discussionId,
            );

            if (belongsToActiveComment && json['user_id'] != currentUserId) {
              loadComments(
                page: state.currentPage,
                silentRealtimeRefresh: true,
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> loadComments({
    int page = 1,
    bool silentRealtimeRefresh = false,
  }) async {
    if (!silentRealtimeRefresh) {
      state = state.copyWith(isLoading: true, currentPage: page);
    } else {
      // Keep current state but update page
      state = state.copyWith(currentPage: page);
    }
    try {
      final repo = ref.read(discussionRepositoryProvider);
      final comments = await repo.getComments(
        mangaId: mangaId,
        chapterId: chapterId,
        limit: 20,
        offset: (page - 1) * 20,
      );
      final total = await repo.getTotalCommentsCount(
        mangaId,
        chapterId: chapterId,
      );

      if (page == 1) {
        state = state.copyWith(
          isLoading: false,
          comments: comments,
          totalCount: total,
        );
      } else {
        // Append comments logic if needed later
        state = state.copyWith(
          isLoading: false,
          comments: comments,
          totalCount: total,
        );
      }
    } catch (e, stack) {
      SecureLogger.logError("DiscussionController loadComments", e, stack);
      if (!silentRealtimeRefresh) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  Future<bool> postComment(
    String text, {
    String? replyToId,
    Map<String, dynamic>? metadata,
    String? chapterNumber,
    String? mangaTitle,
    String? mangaCoverUrl,
    String? mangaDescription,
  }) async {
    if (text.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);
    try {
      final repo = ref.read(discussionRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in");

      await repo.postComment(
        mangaId: mangaId,
        userId: userId,
        textContent: text,
        replyToId: replyToId,
        metadata: metadata,
        chapterId: chapterId,
        chapterNumber: chapterNumber,
        mangaTitle: mangaTitle,
        mangaCoverUrl: mangaCoverUrl,
        mangaDescription: mangaDescription,
      );

      // Refresh first page
      await loadComments(page: 1);
      return true;
    } catch (e, stack) {
      SecureLogger.logError("DiscussionController postComment", e, stack);
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  Future<void> toggleReaction(String commentId, String emoji) async {
    try {
      final repo = ref.read(discussionRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await repo.toggleReaction(
        commentId: commentId,
        userId: userId,
        emoji: emoji,
      );

      // Optimistic update would be better, but refresh for now
      await loadComments(page: state.currentPage);
    } catch (e, stack) {
      SecureLogger.logError("DiscussionController toggleReaction", e, stack);
    }
  }

  Future<bool> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    try {
      final repo = ref.read(discussionRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in");

      await repo.reportComment(
        commentId: commentId,
        reporterId: userId,
        reason: reason,
        details: details,
      );
      return true;
    } catch (e, stack) {
      SecureLogger.logError("DiscussionController reportComment", e, stack);
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final discussionControllerProvider =
    NotifierProvider.family<
      DiscussionController,
      DiscussionState,
      DiscussionArgs
    >(DiscussionController.new);
