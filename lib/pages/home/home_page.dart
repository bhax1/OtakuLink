import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/home/see_more_page.dart';
import 'package:otakulink/theme.dart';
import '../../providers/home_providers.dart';
import 'home_page_widgets/hero_carousel.dart';
import 'home_page_widgets/section_header.dart';
import 'home_page_widgets/horizontal_async_list.dart';
import 'home_page_widgets/personalized_section.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final carouselAsync = ref.watch(trendingMangaProvider(false));
    final newAsync = ref.watch(newReleasesProvider(false));
    final trendingListAsync = ref.watch(trendingListProvider(false));
    final hallOfFameAsync = ref.watch(hallOfFameProvider(false));
    final favoritesAsync = ref.watch(fanFavoritesProvider(false));
    final manhwaAsync = ref.watch(manhwaProvider(false));
    final personalizedAsync = ref.watch(personalizedProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        backgroundColor: Colors.white,
        color: AppColors.accent,
        strokeWidth: 3.0,
        displacement: 40.0,
        onRefresh: () async {
          try {
            await Future.wait([
              ref.refresh(trendingMangaProvider(true).future),
              ref.refresh(newReleasesProvider(true).future),
              ref.refresh(trendingListProvider(true).future),
              ref.refresh(hallOfFameProvider(true).future),
              ref.refresh(fanFavoritesProvider(true).future),
              ref.refresh(manhwaProvider(true).future),
              ref.refresh(personalizedProvider.future),
            ]);
          } catch (e) {
            debugPrint("Refresh error: $e");
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. CAROUSEL
              HeroCarousel(asyncData: carouselAsync),

              const SizedBox(height: 20),

              // 2. PERSONALIZED SECTION
              PersonalizedSection(asyncData: personalizedAsync),
              SectionHeader(
                title: 'Fresh This Season', 
              icon: Icons.calendar_month_outlined, 
              color: Colors.blue,
              onSeeMore: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SeeMorePage(title: 'Fresh This Season', category: CategoryType.newReleases)
              )),
              ),
              HorizontalAsyncList(asyncData: newAsync),
              const SizedBox(height: 20),

              SectionHeader(
                title: 'Trending Now', 
              icon: Icons.local_fire_department, 
              color: Colors.orange,
              onSeeMore: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SeeMorePage(title: 'Trending Now', category: CategoryType.trending)
              )),
              ),
              HorizontalAsyncList(asyncData: trendingListAsync),
              const SizedBox(height: 20),

              SectionHeader(
                title: 'Top Manhwa', 
              icon: Icons.show_chart, 
              color: Colors.redAccent,
              onSeeMore: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SeeMorePage(title: 'Top Manhwa', category: CategoryType.manhwa)
              )),
              ),
              HorizontalAsyncList(asyncData: manhwaAsync),
              const SizedBox(height: 20),

              SectionHeader(
                title: 'Hall of Fame (9.0+)', 
              icon: Icons.emoji_events, 
              color: Colors.amber,
              onSeeMore: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SeeMorePage(title: 'Hall of Fame', category: CategoryType.hallOfFame)
              )),
              ),
              HorizontalAsyncList(asyncData: hallOfFameAsync),
              const SizedBox(height: 20),

              SectionHeader(
                title: 'All-Time Favorites', 
              icon: Icons.favorite, 
              color: Colors.pinkAccent,
              onSeeMore: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SeeMorePage(title: 'All-Time Favorites', category: CategoryType.favorites)
              )),
              ),
              HorizontalAsyncList(asyncData: favoritesAsync),
              const SizedBox(height: 20),

              
            ],
          ),
        ),
      ),
    );
  }
}