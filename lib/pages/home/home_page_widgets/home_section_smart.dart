import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../manga/see_more_page.dart';
import 'section_header.dart';
import 'horizontal_async_list.dart';

class HomeSectionSmart extends ConsumerWidget {
  final String title;
  final IconData icon;
  final Color color;
  final CategoryType category;
  final dynamic provider;

  const HomeSectionSmart({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.category,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(provider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: title,
          icon: icon,
          color: color,
          onSeeMore: () {
            // Logic to format the path parameter
            final String slug = title.toLowerCase().replaceAll(' ', '-');

            context.push(
              '/see-more/$slug',
              extra: {
                'title': title,
                'category': category,
              },
            );
          },
        ),
        HorizontalAsyncList(asyncData: asyncData),
        const SizedBox(height: 20),
      ],
    );
  }
}
