import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/home/manga_details_page.dart';
import 'package:otakulink/pages/home/user_manga_details.dart';

class RecentReadsList extends StatelessWidget {
  final String userId; // Pass the ID of the profile you are looking at

  const RecentReadsList({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Calculate the date 7 days ago
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text("Active This Week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('recent_reads')
                // FILTER: Only show items read after this date
                .where('lastReadAt', isGreaterThan: sevenDaysAgo) 
                .orderBy('lastReadAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              // If empty, show a specific message for "No recent activity"
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, color: Colors.grey[300], size: 40),
                      const SizedBox(height: 8),
                      Text("No reading activity this week", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  
                  return GestureDetector(
                    onTap: () {
                      // Allow clicking to go back to the manga details!

                      final currentUid = FirebaseAuth.instance.currentUser?.uid;

                      if (currentUid == userId) {
                        Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MangaDetailsPage(
                          mangaId: int.parse(data['mangaId']), 
                          userId: userId
                        )
                      ));
                      } else {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => UserMangaPage(
                            mangaId: int.parse(data['mangaId']), 
                            userId: userId
                          )
                        ));
                      }

                      
                    },
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover Image
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: data['cover'],
                                fit: BoxFit.cover,
                                width: 100,
                                placeholder: (c, u) => Container(color: Colors.grey[200]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Title
                          Text(
                            data['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          
                          // Last Chapter Read
                          Text(
                            "Ch. ${data['lastChapter']}",
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}