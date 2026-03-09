import 'package:otakulink/features/reader/data/repositories/reader_repository.dart';
import 'package:otakulink/features/manga/data/repositories/manga_stats_repository.dart';
import 'package:otakulink/features/manga/domain/entities/manga_stats_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:go_router/go_router.dart';

import 'package:otakulink/features/manga/utils/manga_details_utils.dart';
import 'package:otakulink/features/manga/controllers/manga_details_controller.dart';

import 'package:otakulink/core/providers/security_provider.dart';
import 'package:otakulink/core/widgets/verification_banner.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';

import 'widgets/person_card.dart';
import 'widgets/chapter_sheet.dart';
import 'widgets/content_section.dart';
import 'widgets/manga_header.dart';
import 'widgets/manga_info_card.dart';
import 'widgets/user_status_editor.dart';
import 'widgets/read_action_buttons.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/synopsis_section.dart';

class MangaDetailsPage extends ConsumerStatefulWidget {
  final int mangaId;
  const MangaDetailsPage({super.key, required this.mangaId});

  @override
  ConsumerState<MangaDetailsPage> createState() => _MangaDetailsPageState();
}

class _MangaDetailsPageState extends ConsumerState<MangaDetailsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRemovalDialog(MangaDetailsState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove from Library?"),
        content: const Text(
          "Your reading progress will be deleted. You can choose to keep or remove your rating and commentary.",
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref
                      .read(
                        mangaDetailsControllerProvider(widget.mangaId).notifier,
                      )
                      .removeFromLibrary(removeSocial: false);
                },
                child: const Text("Remove Library Only (Keep Social)"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ref
                      .read(
                        mangaDetailsControllerProvider(widget.mangaId).notifier,
                      )
                      .removeFromLibrary(removeSocial: true);
                },
                child: const Text("Remove Everything"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToPersonList(String pageTitle, bool isStaff, List items) {
    if (!mounted) return;
    context.push(
      '/manga/${widget.mangaId}/persons',
      extra: {'title': pageTitle, 'isStaff': isStaff, 'initialItems': items},
    );
  }

  Future<void> _handleMainReadAction(MangaDetailsState state) async {
    if (state.isLoading) return;

    final manga = state.mangaDetails?.manga;
    final title = manga?.titleEnglish ?? manga?.titleRomaji;
    final cover = manga?.coverImageLarge;
    final safeCover = MangaDetailsUtils.isValidSecureUrl(cover) ? cover : '';

    if (title == null ||
        title.toString().trim().isEmpty ||
        title.toString().toLowerCase() == 'unknown') {
      _showDialog("Unavailable", "Manga title is missing or invalid.");
      return;
    }

    bool isDialogShowing = true;
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => isDialogShowing = false);

    try {
      final readerRepo = ref.read(readerRepositoryProvider);
      final chapters = await readerRepo.fetchChapters(title);

      if (!mounted) return;
      if (isDialogShowing) navigator.pop();

      // This safely catches the empty official-only chapters when pressing the main button
      if (chapters.isEmpty) {
        _showDialog("No Chapters", "No chapters found for this manga yet.");
        return;
      }

      int targetIndex = 0;

      if (state.resumePoint != null) {
        final targetId = state.resumePoint!['lastReadId'].toString();
        targetIndex = chapters.indexWhere(
          (ch) => ch['id'].toString() == targetId,
        );
        if (targetIndex == -1) targetIndex = chapters.length - 1;
      } else {
        double minChapterNum = double.infinity;
        targetIndex = chapters.length - 1;

        for (int i = 0; i < chapters.length; i++) {
          final chStr = chapters[i]['chapter'];
          if (chStr != null && chStr.toString().isNotEmpty) {
            final double? chNum = double.tryParse(chStr.toString());
            if (chNum != null && chNum >= 0 && chNum < minChapterNum) {
              minChapterNum = chNum;
              targetIndex = i;
            }
          }
        }
      }

      await context.push(
        '/manga/${widget.mangaId}/read/$targetIndex',
        extra: {
          'initialChapterIndex': targetIndex,
          'allChapters': chapters,
          'mangaId': widget.mangaId.toString(),
          'mangaTitle': title,
          'mangaCover': safeCover,
        },
      );

      ref
          .read(mangaDetailsControllerProvider(widget.mangaId).notifier)
          .refreshResumePoint();
    } catch (e, stack) {
      if (!mounted) return;
      if (isDialogShowing) navigator.pop();
      SecureLogger.logError("MangaDetailsPage _handleMainReadAction", e, stack);
      _showDialog("Error", "Unable to load chapter. Please try again.");
    }
  }

  Future<void> _handleOpenChapters(MangaDetailsState state) async {
    if (state.isLoading) return;

    final title =
        state.mangaDetails?.manga.titleEnglish ??
        state.mangaDetails?.manga.titleRomaji;
    if (title == null ||
        title.toString().trim().isEmpty ||
        title.toString().toLowerCase() == 'unknown') {
      _showDialog("Unavailable", "Manga title is missing or invalid.");
      return;
    }

    bool isDialogShowing = true;
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => isDialogShowing = false);

    try {
      final readerRepo = ref.read(readerRepositoryProvider);
      SecureLogger.info("MangaDetailsPage: Fetching chapters for '$title'");
      final chapters = await readerRepo.fetchChapters(title);
      SecureLogger.info(
        "MangaDetailsPage: Received ${chapters.length} chapters",
      );

      if (!mounted) return;
      if (isDialogShowing) navigator.pop();

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        isScrollControlled: true,
        builder: (_) => ChapterSheet(
          chapters: chapters,
          lastReadId: state.resumePoint?['lastReadId']?.toString(),
          onChapterTap: (index) async {
            final cover = state.mangaDetails?.manga.coverImageLarge;
            final safeCover = MangaDetailsUtils.isValidSecureUrl(cover)
                ? cover
                : '';

            Navigator.pop(context);

            await context.push(
              '/manga/${widget.mangaId}/read/$index',
              extra: {
                'allChapters': chapters,
                'mangaTitle': title,
                'mangaCover': safeCover,
              },
            );

            ref
                .read(mangaDetailsControllerProvider(widget.mangaId).notifier)
                .refreshResumePoint();
          },
        ),
      );
    } catch (e, stack) {
      if (!mounted) return;
      if (isDialogShowing) navigator.pop();
      SecureLogger.logError("MangaDetailsPage _handleOpenChapters", e, stack);
      _showDialog("Error", "Unable to load chapters. Please try again later.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(mangaDetailsControllerProvider(widget.mangaId));
    final securityService = ref.watch(securityServiceProvider);
    final statsAsync = ref.watch(mangaStatsStreamProvider(widget.mangaId));

    ref.listen(mangaDetailsControllerProvider(widget.mangaId), (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.isLoading == false) {
        if (_commentController.text != next.comment) {
          _commentController.text = next.comment;
        }
      }
    });

    return Scaffold(
      body: Column(
        children: [
          VerificationBanner(securityService: securityService),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: uiState.isLoading
                  ? _buildSkeleton()
                  : _buildContent(uiState, statsAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    MangaDetailsState state,
    AsyncValue<MangaStatsEntity?> statsAsync,
  ) {
    if (state.mangaDetails == null) {
      return const Center(child: Text("Manga not found"));
    }

    final theme = Theme.of(context);
    final m = state.mangaDetails!.manga;

    final title = m.titleDisplay;
    final cover = m.coverImageLarge;
    final banner = m.bannerImage;
    final characters = state.mangaDetails!.characters;
    final staff = state.mangaDetails!.staff;
    final recommendations = state.mangaDetails!.recommendations;
    final safeCover = MangaDetailsUtils.isValidSecureUrl(cover) ? cover : null;
    final currentUser = _supabase.auth.currentUser;

    final String publicationStatus = m.status;

    return CustomScrollView(
      key: const ValueKey('Content'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        MangaHeader(
          title: title,
          coverUrl: safeCover,
          bannerUrl: MangaDetailsUtils.isValidSecureUrl(banner) ? banner : null,
          genres: m.genres,
          mangaId: widget.mangaId,
          isLoggedIn: currentUser != null,
          existsInList: state.existsInUserList,
          onCommentsPressed: () {
            if (currentUser != null) {
              context.push(
                '/manga/${widget.mangaId}/discussion',
                extra: {'mangaId': widget.mangaId, 'mangaName': title},
              );
            }
          },
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MangaInfoCard(
                  details: state.mangaDetails!,
                  stats: statsAsync.value,
                ),
                const SizedBox(height: 32),
                ReadActionButtons(
                  resumePoint: state.resumePoint,
                  onMainAction: () => _handleMainReadAction(state),
                  onOpenList: () => _handleOpenChapters(state),
                ),
                const SizedBox(height: 32),
                SynopsisSection(description: state.sanitizedDescription),
                if (currentUser != null) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                  const SizedBox(height: 20),
                  ContentSection(
                    title: "What's Your Take?",
                    child: UserStatusEditor(
                      rating: state.rating,
                      status: state.status,
                      isFavorite: state.isFavorite,
                      isSaving: state.isSaving,
                      existsInList: state.existsInUserList,
                      mangaStatus: publicationStatus,
                      commentController: _commentController,
                      onRatingChanged: (v) => ref
                          .read(
                            mangaDetailsControllerProvider(
                              widget.mangaId,
                            ).notifier,
                          )
                          .updateForm(rating: v),
                      onStatusChanged: (v) {
                        if (v != null) {
                          ref
                              .read(
                                mangaDetailsControllerProvider(
                                  widget.mangaId,
                                ).notifier,
                              )
                              .updateForm(status: v);
                        }
                      },
                      onFavoriteChanged: (v) => ref
                          .read(
                            mangaDetailsControllerProvider(
                              widget.mangaId,
                            ).notifier,
                          )
                          .updateForm(isFavorite: v!),
                      onSave: () async {
                        ref
                            .read(
                              mangaDetailsControllerProvider(
                                widget.mangaId,
                              ).notifier,
                            )
                            .updateForm(comment: _commentController.text);

                        bool success = await ref
                            .read(
                              mangaDetailsControllerProvider(
                                widget.mangaId,
                              ).notifier,
                            )
                            .saveChanges();

                        if (success && mounted) {
                          AppSnackBar.show(
                            context,
                            'Notes saved!',
                            type: SnackBarType.success,
                          );
                        }
                      },
                      onRemove: () => _showRemovalDialog(state),
                    ),
                  ),
                ],
                if (characters.isNotEmpty)
                  ContentSection(
                    title: "Characters",
                    onSeeMore: () =>
                        _navigateToPersonList("Characters", false, characters),
                    child: SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: characters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _buildPersonCard(
                          edge: characters[i],
                          isStaff: false,
                        ),
                      ),
                    ),
                  ),
                if (staff.isNotEmpty)
                  ContentSection(
                    title: "Staff",
                    onSeeMore: () =>
                        _navigateToPersonList("Staff", true, staff),
                    child: SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: staff.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _buildPersonCard(edge: staff[i], isStaff: true),
                      ),
                    ),
                  ),
                if (recommendations.isNotEmpty)
                  ContentSection(
                    title: "You might also like",
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recommendations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => RecommendationCard(
                          recommendation: recommendations[i],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonCard({required dynamic edge, required bool isStaff}) {
    if (edge == null) return const SizedBox.shrink();
    return PersonCard(
      id: edge.id,
      name: edge.name,
      role: edge.role ?? '',
      imageUrl: edge.image ?? '',
      isStaff: isStaff,
      heroTag: '${isStaff ? 'staff' : 'person'}_${widget.mangaId}_${edge.id}',
    );
  }

  Widget _buildSkeleton() {
    return CustomScrollView(
      key: const ValueKey('Skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ],
    );
  }
}
