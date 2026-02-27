import 'package:flutter/material.dart';

class ContentSection extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeMore;
  final Widget child;

  const ContentSection({
    Key? key,
    required this.title,
    required this.child,
    this.onSeeMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color?.withOpacity(0.8),
              ),
            ),
            if (onSeeMore != null)
              InkWell(
                onTap: onSeeMore,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Text(
                        "See More",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.textTheme.titleMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              )
          ],
        ),
        const SizedBox(height: 16),
        child,
        const SizedBox(height: 32),
      ],
    );
  }
}