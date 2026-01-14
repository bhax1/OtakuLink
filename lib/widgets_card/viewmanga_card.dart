import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otakulink/widgets_viewprofile/usermangadetails.dart';
import 'package:otakulink/home_navbar/mangadetails.dart';
import '../main.dart';

class MangaCard extends StatelessWidget {
  final dynamic manga;
  final bool isPlaceholder;
  final String? userId;

  const MangaCard({Key? key, this.manga, this.isPlaceholder = false, this.userId})
      : super(key: key);

  Future<Map<String, dynamic>> _fetchUserMangaData() async {
    if (isPlaceholder || userId == null) return {};

    try {
      final mangaId = manga['mal_id']?.toString();
      if (mangaId == null) return {};

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('manga_ratings')
          .doc(mangaId)
          .get();

      if (doc.exists) return doc.data()!;
    } catch (_) {
      // ignore errors
    }
    return {};
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'reading':
        return Colors.blue;
      case 'on hold':
        return Colors.orange;
      case 'dropped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return GestureDetector(
      onTap: isPlaceholder
          ? null
          : () {
              // check if viewing own commentary
              if (currentUser != null && currentUser.uid == userId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MangaDetailsPage(
                      mangaId: manga['mal_id'], 
                      userId: currentUser.uid,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserMangaPage(
                      mangaId: manga['mal_id'],
                      userId: userId ?? '',
                    ),
                  ),
                );
              }
            },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: Colors.black26,
        child: SizedBox(
          width: 140,
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Manga Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isPlaceholder
                    ? Container(width: 130, height: 160, color: Colors.grey[300])
                    : CachedNetworkImage(
                        imageUrl: manga['images']?['jpg']?['image_url'] ?? '',
                        width: 130,
                        height: 160,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(width: 130, height: 160, color: Colors.grey[300]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, size: 80),
                      ),
              ),
              const SizedBox(height: 8),

              // Manga Title
              isPlaceholder
                  ? Container(width: 120, height: 18, color: Colors.grey[300])
                  : SizedBox(
                      width: 130,
                      child: Text(
                        manga['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              const SizedBox(height: 6),

              // User Data
              if (!isPlaceholder)
                FutureBuilder<Map<String, dynamic>>(
                  future: _fetchUserMangaData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                        'Loading...',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      );
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return const Text(
                        'Error loading data',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      );
                    } else if (snapshot.data!.isEmpty) {
                      return const Text(
                        'Not rated yet',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      );
                    }

                    final data = snapshot.data!;
                    final rating = (data['rating'] ?? 0).toDouble();
                    final status = data['readingStatus'] ?? 'Not Yet';
                    final statusColor = _getStatusColor(status);

                    return Column(
                      children: [
                        // Rating Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$rating',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Status Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
