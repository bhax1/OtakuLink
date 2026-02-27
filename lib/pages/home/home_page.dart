import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/providers/home_providers.dart';
import 'package:otakulink/pages/manga/see_more_page.dart';

import 'package:otakulink/core/api/anilist_service.dart';

import 'home_page_widgets/hero_carousel.dart';
import 'home_page_widgets/home_section_smart.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carouselAsync = ref.watch(trendingMangaProvider);

    final List<_SectionConfig> sections = [
      _SectionConfig('Fresh This Season', Icons.calendar_month_outlined,
          Colors.blue, CategoryType.newReleases, newReleasesProvider),
      _SectionConfig('Trending Now', Icons.local_fire_department, Colors.orange,
          CategoryType.trending, trendingListProvider),
      _SectionConfig('Top Manhwa', Icons.show_chart, Colors.redAccent,
          CategoryType.manhwa, manhwaProvider),
      _SectionConfig('Hall of Fame', Icons.emoji_events, Colors.amber,
          CategoryType.hallOfFame, hallOfFameProvider),
      _SectionConfig('All-Time Favorites', Icons.favorite, Colors.pinkAccent,
          CategoryType.favorites, fanFavoritesProvider),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: Theme.of(context).colorScheme.secondary,
        strokeWidth: 3.0,
        displacement: 40.0,
        onRefresh: () async {
          try {
            await AniListService.invalidateSpecificCaches([
              'anilist_trending_carousel',
              'anilist_new_season',
              'anilist_trending_list',
              'anilist_hall_of_fame',
              'anilist_fan_favorites',
              'anilist_manhwa',
            ]);

            final List<Future<dynamic>> refreshFutures = [
              ref.refresh(trendingMangaProvider.future),
              ...sections.map((s) => ref.refresh(s.provider.future)),
            ];

            await Future.wait(refreshFutures).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint("Refresh timed out: Ending spinner for UX.");
                return [];
              },
            );
          } catch (e) {
            debugPrint("Refresh error: $e");
          }
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  HeroCarousel(asyncData: carouselAsync),
                  const SizedBox(height: 40),
                ],
              );
            }

            final section = sections[index - 1];
            return HomeSectionSmart(
              title: section.title,
              icon: section.icon,
              color: section.color,
              category: section.category,
              provider: section.provider,
            );
          },
        ),
      ),
    );
  }
}

/// Configuration class for Home Sections
class _SectionConfig {
  final String title;
  final IconData icon;
  final Color color;
  final CategoryType category;

  /// Removed the Function(bool) wrapper. Now it just holds the Provider reference.
  final FutureProvider<List<dynamic>> provider;

  _SectionConfig(
    this.title,
    this.icon,
    this.color,
    this.category,
    this.provider,
  );
}
