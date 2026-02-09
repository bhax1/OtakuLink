import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
import 'package:otakulink/theme.dart';

class PendingRequestsPage extends StatefulWidget {
  const PendingRequestsPage({super.key});

  @override
  _PendingRequestsPageState createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  String? _currentUserId;

  late ScaffoldMessengerState scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friends')
            .where('user2Id', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.data?.docs.isEmpty ?? true) {
            return const Center(child: Text('No pending requests.'));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final senderId = request['user1Id'];

              // Only fetch necessary fields from users
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .get(),
                builder: (context, senderSnapshot) {
                  if (senderSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircularProgressIndicator(color: Colors.amber),
                      title: Text('Loading sender info...'),
                    );
                  }

                  if (senderSnapshot.hasError) {
                    return ListTile(
                      title: Text('Error: ${senderSnapshot.error}'),
                    );
                  }

                  final senderData =
                      senderSnapshot.data?.data() as Map<String, dynamic>;

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    ViewProfilePage(userId: senderId),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.fastOutSlowIn;
                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));
                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage: senderData['photoURL'] != null
                            ? CachedNetworkImageProvider(senderData['photoURL'])
                            : const AssetImage('assets/pic/default_avatar.png')
                                as ImageProvider,
                      ),
                    ),
                    title: Text(
                        '${senderData['username']} sent you a friend request'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _handleDecline(senderId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _handleAccept(senderId),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleDecline(String senderId) async {
    if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Friend request declined.')),
      );
    }

    final friendRequestQuery = await FirebaseFirestore.instance
        .collection('friends')
        .where('user1Id', isEqualTo: senderId)
        .where('user2Id', isEqualTo: _currentUserId)
        .get();

    for (var doc in friendRequestQuery.docs) {
      await FirebaseFirestore.instance
          .collection('friends')
          .doc(doc.id)
          .delete();
    }

    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .get();
    final notificationQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('notification')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: _currentUserId)
        .where('edited', isEqualTo: false)
        .where('type', isEqualTo: 'friend_request')
        .get();

    for (var doc in notificationQuery.docs) {
      await doc.reference.update({
        'message': 'Declined friend request from ${senderDoc['username']}.',
        'edited': true,
      });
    }
  }

  Future<void> _handleAccept(String senderId) async {
    if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Friend request accepted.')),
      );
    }

    final friendRequestDoc = await FirebaseFirestore.instance
        .collection('friends')
        .where('user1Id', isEqualTo: senderId)
        .where('user2Id', isEqualTo: _currentUserId)
        .limit(1)
        .get();

    if (friendRequestDoc.docs.isNotEmpty) {
      await friendRequestDoc.docs.first.reference.update({
        'status': 'friends',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .update({
      'friends': FieldValue.arrayUnion([senderId]),
      'friendsCount': FieldValue.increment(1),
    });

    await FirebaseFirestore.instance.collection('users').doc(senderId).update({
      'friends': FieldValue.arrayUnion([_currentUserId]),
      'friendsCount': FieldValue.increment(1),
    });

    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .get();
    final notificationQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('notification')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: _currentUserId)
        .where('edited', isEqualTo: false)
        .where('type', isEqualTo: 'friend_request')
        .get();

    for (var doc in notificationQuery.docs) {
      await doc.reference.update({
        'message': 'Accepted friend request from ${senderDoc['username']}.',
        'edited': true,
      });
    }
  }
}
