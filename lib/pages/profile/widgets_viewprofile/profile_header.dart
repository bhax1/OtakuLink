import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/theme.dart';

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> userProfile;
  final Stream<Map<String, String>> countsStream;

  const ProfileHeader({
    Key? key,
    required this.userProfile,
    required this.countsStream,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. AVATAR WITH RING
        Container(
          padding: const EdgeInsets.all(3), // Space between ring and image
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2), // The Ring
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: userProfile['photoURL'] != null
                ? CachedNetworkImageProvider(userProfile['photoURL'])
                : null,
            child: userProfile['photoURL'] == null
                ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                : null,
          ),
        ),

        const SizedBox(height: 12),

        // 2. USERNAME (Added mainly because viewing others needs context)
        Text(
          userProfile['username'] ?? 'Unknown',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 24),

        // 3. STATS ROW
        StreamBuilder<Map<String, String>>(
          stream: countsStream,
          builder: (context, snapshot) {
            final counts = snapshot.data ?? {'followers': '0', 'friends': '0'};
            
            // Parse strings back to int for formatting if needed, 
            // or just trust the stream sends formatted strings.
            // Assuming stream sends raw numbers as strings:
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Followers', counts['followers'] ?? '0'),
                
                // Vertical Divider
                Container(
                  height: 30, 
                  width: 1, 
                  color: Colors.grey[300]
                ),
                
                _buildStatItem('Friends', counts['friends'] ?? '0'),
              ],
            );
          },
        ),
      ],
    );
  }

  // Helper widget to match UserHeader style
  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}