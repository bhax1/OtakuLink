import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'package:otakulink/home_navbar/viewprofile.dart';
import 'package:otakulink/main.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String? _currentUserId;
  String? username;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _markNotificationsAsRead();
    _loadData();
  }

  Future<void> _markNotificationsAsRead() async {
    if (_currentUserId == null) return;
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('notification')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var notification in notificationsSnapshot.docs) {
        await notification.reference.update({'isRead': true});
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_currentUserId == null) return;

    try {
      final notificationsQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('notification')
          .where('receiverId', isEqualTo: _currentUserId);

      final batch = FirebaseFirestore.instance.batch();
      final notificationsSnapshot = await notificationsQuery.get();

      for (var doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _loadData() async {
    var box = await Hive.openBox('userCache');

    username = box.get('username');
    if (username == null && _currentUserId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();

        if (userDoc.exists) {
          username = userDoc['username'];
          await box.put('username', username);
        }
      } catch (e) {
        print('Error fetching username from Firestore: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Notifications'),
                  content: const Text(
                      'Are you sure you want to delete all notifications?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _clearAllNotifications();
                      },
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notification')
            .where('receiverId', isEqualTo: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.data?.docs.isEmpty ?? true) {
            return const Center(child: Text('No new notifications.'));
          }

          final notifications = snapshot.data!.docs;

          // Sort notifications by timestamp in descending order
          notifications.sort((a, b) {
            final timeA = a['timestamp'] as Timestamp;
            final timeB = b['timestamp'] as Timestamp;
            return timeB.compareTo(timeA); // Descending order
          });

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final senderId = notification['senderId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .get(),
                builder: (context, senderSnapshot) {
                  if (senderSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Loading sender info...'),
                    );
                  }

                  if (senderSnapshot.hasError) {
                    return ListTile(
                      title: Text('Error: ${senderSnapshot.error}'),
                    );
                  }

                  final senderData =
                      senderSnapshot.data?.data() as Map<String, dynamic>?;

                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) async {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Notification deleted')),
                        );
                      }
                      await notification.reference.delete();
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                    ),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) {
                                return ViewProfilePage(userId: senderId);
                              },
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
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
                        child: CircleAvatar(
                          backgroundImage: senderData?['photoURL'] != null
                              ? CachedNetworkImageProvider(
                                  senderData!['photoURL'])
                              : const AssetImage(
                                      'assets/pic/default_avatar.png')
                                  as ImageProvider,
                        ),
                      ),
                      title: Text(notification['message']),
                      trailing: notification['edited'] == true
                          ? null // Hide buttons if edited is true
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () async {
                                    // Handle decline action
                                    print(senderId);
                                    final friendRequestQuery =
                                        await FirebaseFirestore.instance
                                            .collection('friends')
                                            .where('user1Id',
                                                isEqualTo: senderId)
                                            .where('user2Id',
                                                isEqualTo: _currentUserId)
                                            .get();

                                    for (var doc in friendRequestQuery.docs) {
                                      await FirebaseFirestore.instance
                                          .collection('friends')
                                          .doc(doc.id)
                                          .delete();
                                    }

                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Friend request declined.')),
                                      );
                                    }
                                    DocumentSnapshot senderDoc =
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(senderId)
                                            .get();
                                    await notification.reference.update({
                                      'message':
                                          'Declined friend request from ${senderDoc['username']}.',
                                      'edited': true
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () async {
                                    // Handle accept action
                                    final friendRequestDoc =
                                        await FirebaseFirestore.instance
                                            .collection('friends')
                                            .where('user1Id',
                                                isEqualTo: senderId)
                                            .where('user2Id',
                                                isEqualTo: _currentUserId)
                                            .limit(1)
                                            .get();

                                    if (friendRequestDoc.docs.isNotEmpty) {
                                      final docRef =
                                          friendRequestDoc.docs.first.reference;

                                      await docRef.update({
                                        'status': 'friends',
                                        'timestamp': FieldValue.serverTimestamp(),
                                      });
                                    }
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_currentUserId)
                                        .update({
                                      'friends':
                                          FieldValue.arrayUnion([senderId])
                                    });
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(senderId)
                                        .update({
                                      'friends': FieldValue.arrayUnion(
                                          [_currentUserId])
                                    });

                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Friend request accepted.')),
                                      );
                                    }
                                    DocumentSnapshot senderDoc =
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(senderId)
                                            .get();
                                    await notification.reference.update({
                                      'message':
                                          'Accepted friend request from ${senderDoc['username']}.',
                                      'edited': true
                                    });

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_currentUserId)
                                        .update({
                                      'friendsCount': FieldValue.increment(1),
                                    });

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(senderId)
                                        .update({
                                      'friendsCount': FieldValue.increment(1),
                                    });
                                  },
                                ),
                              ],
                            ),
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
}
