import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MangaHeader extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final String? bannerUrl;
  final List<dynamic> genres;
  final int mangaId;
  final bool isLoggedIn;
  final bool existsInList;
  final VoidCallback? onCommentsPressed;
  final VoidCallback? onDeletePressed;

  const MangaHeader({
    Key? key,
    required this.title,
    this.coverUrl,
    this.bannerUrl,
    required this.genres,
    required this.mangaId,
    required this.isLoggedIn,
    required this.existsInList,
    this.onCommentsPressed,
    this.onDeletePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeBanner = bannerUrl ?? coverUrl;

    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      backgroundColor: theme.colorScheme.primary,
      leadingWidth: 100,
      leading: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const BackButton(),
            IconButton(
              icon: const Icon(Icons.home_filled),
              tooltip: "Back to Home",
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
      actions: [
        if (isLoggedIn)
          IconButton(
            icon: const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.forum),
            ),
            tooltip: "Comments",
            onPressed: onCommentsPressed,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (safeBanner != null)
              CachedNetworkImage(
                imageUrl: safeBanner,
                fit: BoxFit.cover,
                memCacheHeight: 1000,
                placeholder: (context, url) =>
                    Container(color: theme.colorScheme.primary),
                errorWidget: (context, url, error) =>
                    Container(color: Colors.grey),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Hero(
                  tag: 'manga_$mangaId',
                  child: Container(
                    height: 200,
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    // --- OPTIMIZATION: RAM/GPU Safe Rendering ---
                    child: coverUrl != null && coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl!,
                            memCacheHeight: 400, // Safe RAM cap
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(color: Colors.black, blurRadius: 10)
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (genres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: genres.take(4).map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            g.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
