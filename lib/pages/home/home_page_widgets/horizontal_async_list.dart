import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/manga/manga_widgets/manga_card.dart';
import 'simple_manga_list.dart';

class HorizontalAsyncList extends StatelessWidget {
  final AsyncValue<dynamic> asyncData;

  const HorizontalAsyncList({super.key, required this.asyncData});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        child: asyncData.when(
          data: (data) {
            final listData = data is List ? data : [];
            return SimpleMangaList(data: listData);
          },
          loading: () => ListView.separated(
            key: const ValueKey('loading_skeleton'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SizedBox(
              width: 140,
              child: MangaCard(isPlaceholder: true),
            ),
          ),
          error: (err, stack) => Center(
            key: const ValueKey('error_state'),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading data',
                    style: TextStyle(color: Colors.red[300], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
