import '../entities/discussion_entities.dart';

abstract class IDiscussionRepository {
  Stream<List<DiscussionComment>> watchComments(
    int mangaId, {
    String? chapterId,
  });

  Future<List<DiscussionComment>> getComments({
    required int mangaId,
    String? chapterId,
    int limit = 20,
    int offset = 0,
  });

  Future<void> postComment({
    required int mangaId,
    required String userId,
    required String textContent,
    String? replyToId,
    Map<String, dynamic>? metadata,
    String? chapterId,
    String? chapterNumber,
    String? mangaTitle,
    String? mangaCoverUrl,
    String? mangaDescription,
  });

  Future<void> deleteComment(String commentId);

  Future<void> toggleReaction({
    required String commentId,
    required String userId,
    required String emoji,
  });

  Future<void> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
    String? details,
  });

  Future<int> getTotalCommentsCount(int mangaId, {String? chapterId});

  Future<int> getCommentPageNumber({
    required int mangaId,
    required String commentId,
    String? chapterId,
    int itemsPerPage = 20,
  });
}
