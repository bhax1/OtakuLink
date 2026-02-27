import 'package:flutter/material.dart';
import 'package:otakulink/pages/manga/manga_widgets/manga_card.dart';

class SimpleMangaList extends StatelessWidget {
  final List<dynamic> data;

  const SimpleMangaList({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(height: 260, child: Center(child: Text('No data found')));
    }

    return SizedBox(
      height: 260,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 140,
          child: MangaCard(manga: data[index]), 
        ),
      ),
    );
  }
}