import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/home/manga_details_page.dart';

class HeroCarousel extends StatefulWidget {
  final AsyncValue<List<dynamic>> asyncData;
  const HeroCarousel({super.key, required this.asyncData});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return widget.asyncData.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
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

                  // --- UPDATED KEYS FOR ANILIST ---
                  
                  // 1. Image Priority: Banner -> XL Cover -> Large Cover
                  final String imgUrl = item['bannerImage'] 
                      ?? item['coverImage']['extraLarge'] 
                      ?? item['coverImage']['large'] 
                      ?? '';

                  // 2. Title: Use the 'display' key we created in the service
                  final String title = item['title']['display'] ?? 'Unknown Title';
                  
                  // 3. ID
                  final int id = item['id'];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MangaDetailsPage(
                            mangaId: id,
                            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) => Container(color: Colors.grey[800]),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.transparent,
                                Colors.black.withOpacity(0.95),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 50, left: 20, right: 20,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: Text('#${index + 1} TRENDING', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title, 
                                textAlign: TextAlign.center, 
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 32, 
                                  fontWeight: FontWeight.w900, 
                                  shadows: [Shadow(color: Colors.black, blurRadius: 10)]
                                ), 
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis
                              ),
                              const SizedBox(height: 10),
                              
                              // Handle Genres safely
                              if (item['genres'] != null && (item['genres'] as List).isNotEmpty)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: (item['genres'] as List).take(3).map<Widget>((g) {
                                    return Text('• $g', style: const TextStyle(color: Colors.white70, fontSize: 12));
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
                      decoration: BoxDecoration(color: _currentPage == index ? Colors.redAccent : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(4)),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(height: 450, color: Colors.grey[900]),
      error: (_, __) => Container(height: 450, color: Colors.grey[900], child: const Center(child: Icon(Icons.error))),
    );
  }
}