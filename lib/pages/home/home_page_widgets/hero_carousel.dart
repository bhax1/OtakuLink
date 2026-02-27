import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HeroCarousel extends ConsumerStatefulWidget {
  final AsyncValue<List<dynamic>> asyncData;
  const HeroCarousel({super.key, required this.asyncData});

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return widget.asyncData.when(
      data: (data) {
        if (data.isEmpty) return const _DefaultHero();

        final carouselData = data.take(8).toList();

        return SizedBox(
          height: 450,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: carouselData.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final item = carouselData[index];
                  final String imgUrl = item['coverImage']['extraLarge'] ??
                      item['coverImage']['large'] ??
                      '';
                  final String title = item['title']['english'] ??
                      item['title']['romaji'] ??
                      'Unknown Title';

                  return GestureDetector(
                    onTap: () => context.push('/manga/${item['id']}'),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          // Use theme surface color for placeholder
                          placeholder: (context, url) =>
                              Container(color: colorScheme.surface),
                          errorWidget: (context, url, error) => Container(
                              color: colorScheme.surface,
                              child: Icon(Icons.broken_image,
                                  color: theme.disabledColor)),
                        ),
                        // Gradient Overlay (Always Dark for text readability)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                                Colors.black.withOpacity(0.95),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                        // Text Content (Keep White because it's on a dark overlay)
                        Positioned(
                          bottom: 50,
                          left: 20,
                          right: 20,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    // Use Theme Secondary (Accent)
                                    color: colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('#${index + 1} TRENDING',
                                    style: const TextStyle(
                                        color: Colors.white, // Text on accent
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 10),
                              Text(title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors
                                          .white, // Always white on dark overlay
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              if (item['genres'] != null)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: (item['genres'] as List)
                                      .take(3)
                                      .map<Widget>((g) {
                                    return Text('• $g',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12));
                                  }).toList(),
                                ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
              // Indicators
              Positioned(
                bottom: 15,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(carouselData.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          // Active: Theme Secondary, Inactive: White/Transparent
                          color: _currentPage == index
                              ? colorScheme.secondary
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4)),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const _HeroSkeleton(),
      error: (err, stack) {
        // If the API throws a TimeoutException, Riverpod catches it here.
        final isTimeout = err is TimeoutException;
        return _DefaultHero(isTimeout: isTimeout);
      },
    );
  }
}

// --- 1. SKELETON WIDGET (Themed) ---
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Determine placeholder color based on brightness
    final baseColor = theme.colorScheme.surface;
    final boneColor =
        theme.brightness == Brightness.dark ? Colors.white10 : Colors.black12;

    return Container(
      height: 450,
      color: baseColor,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Container(width: 80, height: 20, color: boneColor),
                const SizedBox(height: 15),
                Container(width: double.infinity, height: 30, color: boneColor),
                const SizedBox(height: 8),
                Container(width: 150, height: 30, color: boneColor),
                const SizedBox(height: 15),
                Container(width: 200, height: 15, color: boneColor),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- 2. DEFAULT WIDGET (Themed) ---
class _DefaultHero extends StatelessWidget {
  final bool isTimeout;
  const _DefaultHero({this.isTimeout = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 450,
      width: double.infinity,
      decoration: BoxDecoration(
        // Uses Primary -> Secondary gradient from your AppTheme
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  isTimeout ? Icons.timer_off_outlined : Icons.wifi_off_rounded,
                  size: 60,
                  // Ensure icon contrasts with Primary Color
                  color: colorScheme.onPrimary.withOpacity(0.7)),
              const SizedBox(height: 16),
              Text(
                "OtakuLink",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isTimeout ? "Taking too long..." : "Welcome to the Hub",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
