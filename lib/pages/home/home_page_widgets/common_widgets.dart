import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/home/manga_widgets/manga_card.dart';

// --- A Reusable Header ---
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --- A Reusable Horizontal List (Handles Loading/Error) ---
class HorizontalMangaList extends StatelessWidget {
  final AsyncValue<List<dynamic>> asyncData;

  const HorizontalMangaList({super.key, required this.asyncData});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: asyncData.when(
        data: (data) {
          if (data.isEmpty) return const Center(child: Text('No data found'));
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => MangaCard(
              manga: data[index],
              // Assuming you handle UserID inside MangaCard or pass it here
            ),
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const MangaCard(isPlaceholder: true),
        ),
        error: (err, __) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}