import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/home/person_details_page.dart';

class PersonCard extends StatelessWidget {
  final int id;
  final String name;
  final String role;
  final String imageUrl;
  final bool isStaff;
  final bool darkMode;
  final Object heroTag; // <--- ADD THIS

  const PersonCard({
    super.key,
    required this.id,
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.heroTag, // <--- ADD THIS
    this.isStaff = false,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkMode ? Colors.white : Colors.black;
    final subTextColor = darkMode ? Colors.white60 : Colors.grey[600];

    return GestureDetector(
      onTap: () {
        // IMPROVED TRANSITION: Fade Route + Pass Hero Tag
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: PersonDetailsPage(
                  id: id, 
                  isStaff: isStaff,
                  heroTag: heroTag, // Pass the tag forward
                ),
              );
            },
          ),
        );
      },
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            // Avatar Container with Border
            // MOVED HERO HERE (Wrapping only the image)
            Hero(
              tag: heroTag,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: darkMode ? Colors.white24 : Colors.grey[200]!, width: 2),
                  boxShadow: darkMode ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: CachedNetworkImageProvider(imageUrl),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: subTextColor),
            ),
          ],
        ),
      ),
    );
  }
}