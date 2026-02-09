import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/home/home_page_widgets/section_header.dart';
import 'package:otakulink/pages/home/home_page_widgets/simple_manga_list.dart';

class PersonalizedSection extends StatelessWidget {
  final AsyncValue<dynamic> asyncData;

  const PersonalizedSection({super.key, required this.asyncData});

  @override
  Widget build(BuildContext context) {
    return asyncData.when(
      data: (data) {
        // If no data or null, show nothing (don't take up space)
        if (data == null) return const SizedBox.shrink();

        return Column(
          children: [
            SectionHeader(
              title: 'Because you liked ${data['sourceTitle']}',
              icon: Icons.recommend,
              color: Colors.purple,
            ),
            SimpleMangaList(data: data['data']),
            const SizedBox(height: 20),
          ],
        );
      },
      // Hide section completely if loading or error
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Recommendation Error: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}