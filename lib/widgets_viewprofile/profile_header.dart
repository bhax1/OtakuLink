import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    return Row(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: userProfile['photoURL'] != null
              ? CachedNetworkImageProvider(userProfile['photoURL'])
              : null,
          child: userProfile['photoURL'] == null
              ? const Icon(Icons.person, size: 50)
              : null,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: userProfile['username'] ?? 'N/A',
                child: Text(
                  userProfile['username'] ?? 'N/A',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 5),
              StreamBuilder<Map<String, String>>(
                stream: countsStream,
                builder: (context, snapshot) {
                  final counts = snapshot.data ?? {'followers': '0', 'friends': '0'};
                  return Row(
                    children: [
                      Text('${counts['followers']} Followers'),
                      const SizedBox(width: 10),
                      Text('${counts['friends']} Friends'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
