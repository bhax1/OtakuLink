import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/discussion_entities.dart';
import '../../domain/repositories/i_discussion_repository.dart';

class SupabaseDiscussionRepository implements IDiscussionRepository {
  final SupabaseClient _client;

  SupabaseDiscussionRepository(this._client);

  @override
  Future<List<DiscussionComment>> getComments({
    required int mangaId,
    String? chapterId,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('discussions')
        .select('''
          *,
          profiles:user_id (username, avatar_url),
          reactions:discussion_reactions (*)
        ''')
        .eq('manga_id', mangaId);

    if (chapterId != null) {
      query = query.eq('chapter_id', chapterId);
    } else {
      query = query.filter('chapter_id', 'is', null);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) {
      final profile = json['profiles'];
      final reactionsList = (json['reactions'] as List? ?? []);

      return DiscussionComment(
        id: json['id'],
        mangaId: json['manga_id'],
        userId: json['user_id'],
        username: profile?['username'] ?? 'Anonymous',
        avatarUrl: profile?['avatar_url'],
        textContent: json['text_content'],
        replyToId: json['reply_to_id'],
        metadata: json['metadata'],
        chapterId: json['chapter_id'],
        chapterNumber: json['chapter_number'],
        createdAt: DateTime.parse(json['created_at']),
        reactions: reactionsList
            .map(
              (r) => DiscussionReaction(
                discussionId: r['discussion_id'],
                userId: r['user_id'],
                emoji: r['emoji'],
              ),
            )
            .toList(),
      );
    }).toList();
  }

  @override
  Stream<List<DiscussionComment>> watchComments(
    int mangaId, {
    String? chapterId,
  }) {
    return _client
        .from('discussions')
        .stream(primaryKey: ['id'])
        .eq('manga_id', mangaId)
        .map(
          (data) => data
              .where((json) {
                if (chapterId != null) {
                  return json['chapter_id'] == chapterId;
                } else {
                  return json['chapter_id'] == null;
                }
              })
              .map((json) {
                return DiscussionComment(
                  id: json['id'],
                  mangaId: json['manga_id'],
                  userId: json['user_id'],
                  username: 'Loading...', // Temporary
                  textContent: json['text_content'],
                  chapterId: json['chapter_id'],
                  createdAt: DateTime.parse(json['created_at']),
                );
              })
              .toList(),
        );
  }

  @override
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
  }) async {
    // Sync manga metadata first if provided to avoid FK violation
    if (mangaTitle != null) {
      await _client.rpc(
        'sync_manga_metadata',
        params: {
          'p_id': mangaId,
          'p_title': mangaTitle,
          'p_cover_url': mangaCoverUrl,
          'p_description': mangaDescription,
        },
      );
    }

    final response = await _client
        .from('discussions')
        .insert({
          'manga_id': mangaId,
          'user_id': userId,
          'text_content': textContent,
          'reply_to_id': replyToId,
          'metadata': metadata,
          'chapter_id': chapterId,
          'chapter_number': chapterNumber,
        })
        .select('id')
        .single();

    final discussionId = response['id'] as String;

    // --- MENTION DETECTION ---
    final mentionRegex = RegExp(r"\@(\w+)");
    final matches = mentionRegex.allMatches(textContent);
    final mentionedUsernames = matches.map((m) => m.group(1)!).toSet();

    if (mentionedUsernames.isNotEmpty) {
      for (final username in mentionedUsernames) {
        try {
          final profile = await _client
              .from('profiles')
              .select('id')
              .eq('username', username)
              .maybeSingle();

          if (profile != null) {
            final targetUserId = profile['id'] as String;
            if (targetUserId != userId) {
              // Only notify if not already notified as parent via trigger
              bool isParent = false;
              if (replyToId != null) {
                final parent = await _client
                    .from('discussions')
                    .select('user_id')
                    .eq('id', replyToId)
                    .maybeSingle();
                if (parent != null && parent['user_id'] == targetUserId) {
                  isParent = true;
                }
              }

              if (!isParent) {
                await _client.from('notifications').insert({
                  'user_id': targetUserId,
                  'type': 'mention',
                  'manga_id': mangaId,
                  'chapter_id': chapterId,
                  'chapter_number': chapterNumber,
                  'discussion_id': discussionId,
                  'actor_id': userId,
                });
              }
            }
          }
        } catch (e) {
          // Silent fail for profile lookup/notif insertion
        }
      }
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('discussions').delete().eq('id', commentId);
  }

  @override
  Future<void> toggleReaction({
    required String commentId,
    required String userId,
    required String emoji,
  }) async {
    // Check if reaction exists
    final exists = await _client
        .from('discussion_reactions')
        .select()
        .eq('discussion_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (exists != null && exists['emoji'] == emoji) {
      // Remove
      await _client
          .from('discussion_reactions')
          .delete()
          .eq('discussion_id', commentId)
          .eq('user_id', userId);
    } else {
      // Upsert
      await _client.from('discussion_reactions').upsert({
        'discussion_id': commentId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  @override
  Future<void> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    await _client.from('content_reports').insert({
      'reporter_id': reporterId,
      'content_type': 'discussion',
      'content_id': commentId,
      'reason': reason,
      'details': details,
    });
  }

  @override
  Future<int> getTotalCommentsCount(int mangaId, {String? chapterId}) async {
    var query = _client
        .from('discussions')
        .select('id')
        .eq('manga_id', mangaId);

    if (chapterId != null) {
      query = query.eq('chapter_id', chapterId);
    } else {
      query = query.filter('chapter_id', 'is', null);
    }

    final response = await query;
    return (response as List).length;
  }

  @override
  Future<int> getCommentPageNumber({
    required int mangaId,
    required String commentId,
    String? chapterId,
    int itemsPerPage = 20,
  }) async {
    // We need to find how many comments are 'newer' than this one to find its index.
    // Our ordering is created_at DESC.
    final targetComment = await _client
        .from('discussions')
        .select('created_at')
        .eq('id', commentId)
        .single();

    final createdAt = targetComment['created_at'];

    var query = _client
        .from('discussions')
        .select('id')
        .eq('manga_id', mangaId)
        .gt('created_at', createdAt);

    if (chapterId != null) {
      query = query.eq('chapter_id', chapterId);
    } else {
      query = query.filter('chapter_id', 'is', null);
    }

    final response = await query;
    final newerCount = (response as List).length;

    return (newerCount / itemsPerPage).floor() + 1;
  }
}
