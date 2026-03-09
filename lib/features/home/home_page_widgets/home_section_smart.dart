import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/home_providers.dart';
import 'common_widgets.dart';
import 'horizontal_async_list.dart';

class HomeSectionSmart extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final CategoryType category;
  final FutureProvider<List<dynamic>> provider;

  const HomeSectionSmart({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.category,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final asyncData = ref.watch(provider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title, icon: icon, color: color),
            HorizontalAsyncList(asyncData: asyncData),
            const SizedBox(height: 24), // Breathing room between rows
          ],
        );
      },
    );
  }
}
