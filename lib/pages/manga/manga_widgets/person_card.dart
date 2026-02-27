import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PersonCard extends StatelessWidget {
  final int id;
  final String name;
  final String role;
  final String imageUrl;
  final bool isStaff;
  final Object heroTag;

  const PersonCard({
    super.key,
    required this.id,
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.heroTag,
    this.isStaff = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return GestureDetector(
      onTap: () {
        context.push(
          '/person/$id',
          extra: {
            'isStaff': isStaff,
            'heroTag': heroTag,
          },
        );
      },
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            Hero(
              tag: heroTag,
              child: Container(
                height: 80, // Explicitly size the container (Radius 40 * 2)
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: colorScheme.onSurface.withOpacity(0.1), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),

                // --- OPTIMIZATION: Swapped CircleAvatar for CachedNetworkImage ---
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,

                        // Limits RAM allocation (80 logical pixels * ~2.0 device pixel ratio)
                        memCacheHeight: 160,
                        memCacheWidth: 160,

                        // Hardware-accelerated circle clipping
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(Icons.person,
                              color: colorScheme.onSurface.withOpacity(0.5)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(Icons.person_off,
                              color: colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        child: Icon(Icons.person,
                            color: colorScheme.onSurface.withOpacity(0.5)),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                  fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
