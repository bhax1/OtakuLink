import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otakulink/pages/home/manga_details_page.dart';
// Import both pages: One for viewing others, one for editing your own
import 'package:otakulink/pages/home/user_manga_details.dart';

class MangaCard extends StatelessWidget {
  final dynamic manga;
  final bool isPlaceholder;
  final String? userId;

  const MangaCard({
    Key? key, 
    this.manga, 
    this.isPlaceholder = false, 
    this.userId
  }) : super(key: key);

  // --- FETCH USER RATING FROM FIRESTORE ---
  Future<Map<String, dynamic>> _fetchUserMangaData() async {
    if (isPlaceholder || userId == null) return {};

    try {
      final String mangaId = (manga['id'] ?? manga['mangaId'])?.toString() ?? '';
      
      if (mangaId.isEmpty) return {};

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('manga_ratings')
          .doc(mangaId)
          .get();

      if (doc.exists) return doc.data()!;
    } catch (e) {
      debugPrint("Error fetching user rating: $e");
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (isPlaceholder) return _buildPlaceholder();

    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Data Extraction
    final String title = manga['title'] ?? manga['title_english'] ?? 'Unknown';
    final String imageUrl = manga['images']?['jpg']?['large_image_url'] ?? 
                            manga['image'] ?? 
                            manga['coverImage']?['large'] ?? '';

    // ID Extraction for Navigation
    final int navId = manga['id'] ?? manga['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        if (currentUser != null && currentUser.uid == userId) {
          // CASE 1: MY PROFILE -> Go to Edit/Update Page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MangaDetailsPage(
                mangaId: navId, 
                userId: currentUser.uid,
              ),
            ),
          );
        } else {
          // CASE 2: THEIR PROFILE -> Go to View Only Page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserMangaPage(
                mangaId: navId,
                userId: userId ?? '',
              ),
            ),
          );
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE & OVERLAYS
            Stack(
              children: [
                // 1. Poster Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 140,
                    height: 190,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200], height: 190),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300], 
                      height: 190, 
                      child: const Icon(Icons.broken_image, color: Colors.grey)
                    ),
                  ),
                ),
                
                // 2. User Stats Overlay (Rating & Status)
                Positioned.fill(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _fetchUserMangaData(),
                    builder: (context, snapshot) {
                      // If loading or no data yet, show nothing
                      if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final data = snapshot.data!;
                      final rating = (data['rating'] ?? 0).toDouble();
                      final status = data['readingStatus'] ?? 'reading';
                      
                      // Format Rating: "9.0" -> "9", "8.5" -> "8.5"
                      final String ratingText = rating % 1 == 0 ? rating.toInt().toString() : rating.toString();
                      
                      return Stack(
                        children: [
                          // Top Right: Status Badge
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white
                                ),
                              ),
                            ),
                          ),

                          // Bottom Left: Rating Badge
                          if (rating > 0) 
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    ratingText,
                                    style: const TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w800, 
                                      color: Colors.white
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // TITLE
            SizedBox(
              height: 36,
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 140,
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(height: 190, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 8),
          Container(height: 12, width: 80, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'reading': return Colors.blue;
      case 'on hold': return Colors.orange;
      case 'dropped': return Colors.red;
      case 'plan to read': return Colors.purple;
      default: return Colors.grey;
    }
  }
}