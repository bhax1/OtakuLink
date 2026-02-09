import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/home/manga_widgets/manga_card.dart';
import 'package:otakulink/pages/home/home_page_widgets/simple_manga_list.dart';

class HorizontalAsyncList extends StatelessWidget {
  final AsyncValue<List<dynamic>> asyncData;

  const HorizontalAsyncList({super.key, required this.asyncData});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: asyncData.when(
        data: (data) => SimpleMangaList(data: data),
        loading: () => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const SizedBox(
            width: 140,
            child: MangaCard(isPlaceholder: true),
          ),
        ),
        error: (err, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Error: ${err.toString()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}