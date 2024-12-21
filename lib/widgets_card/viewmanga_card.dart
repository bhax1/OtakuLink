import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/widgets_viewprofile/usermangadetails.dart';
import '../main.dart';

class MangaCard extends StatelessWidget {
  final dynamic manga;
  final bool isPlaceholder;
  final String? userId;

  const MangaCard({Key? key, this.manga, this.isPlaceholder = false, this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaceholder
          ? null
          : () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return UserMangaPage(
                      mangaId: manga['mal_id'],
                      userId: userId ?? '',
                    );
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.fastOutSlowIn;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
        child: SizedBox(
          width: 130,
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isPlaceholder)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: manga?['images']?['jpg']?['image_url'] ?? '',
                    width: 120,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      width: 120,
                      height: 150,
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 100),
                  ),
                )
              else
                Container(
                  width: 120,
                  height: 150,
                  color: Colors.grey[300],
                ),
              const SizedBox(height: 10),
              if (!isPlaceholder)
                SizedBox(
                  width: 120,
                  child: Text(
                    manga?['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Container(
                  width: 120,
                  height: 16,
                  color: Colors.grey[300],
                ),
            ],
          ),
        ),
      ),
    );
  }
}