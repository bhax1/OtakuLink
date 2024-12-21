import 'package:flutter/material.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/widgets_viewprofile/friend_service.dart';

class FriendButtons extends StatefulWidget {
  final String userId;
  final String? currentUserId;

  const FriendButtons(
      {Key? key, required this.userId, required this.currentUserId})
      : super(key: key);

  @override
  _FriendButtonsState createState() => _FriendButtonsState();
}

class _FriendButtonsState extends State<FriendButtons> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: FriendService.getFriendStatusStream(
          widget.userId, widget.currentUserId),
      builder: (context, snapshot) {
        Widget child;

        if (snapshot.connectionState == ConnectionState.waiting) {
          child = ElevatedButton(
            key: ValueKey('loading'),
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              minimumSize: const Size(125, 50),
            ),
            child: const Text(''),
          );
        } else if (snapshot.hasError) {
          child = Center(
            key: ValueKey('error'),
            child: Text('Error: ${snapshot.error}'),
          );
        } else if (snapshot.hasData) {
          final status = snapshot.data;
          if (status == 'friends') {
            child = SizedBox(
              width: 125,
              child: DropdownButton<String>(
                dropdownColor: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                key: const ValueKey('friends'),
                hint: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(125, 50),
                  ),
                  child: const Text(
                    'Friends',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                items: ['Unfriend', 'Cancel']
                    .map((item) => DropdownMenuItem<String>(
                          value: item.toLowerCase(),
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: (String? action) async {
                  if (action == 'unfriend') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Unfriend'),
                          content: const Text(
                              'Are you sure you want to unfriend this user?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text(
                                'Unfriend',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm == true) {
                      FriendService.unfriend(
                          widget.userId, widget.currentUserId);
                    }
                  }
                },
                underline: const SizedBox(),
                icon: const SizedBox(),
              ),
            );
          } else if (status == 'sent') {
            child = ElevatedButton(
              key: ValueKey('sent'),
              onPressed: () => FriendService.cancelRequest(
                  widget.userId, widget.currentUserId, 'cancelled'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(125, 50),
                backgroundColor: Colors.redAccent.shade200,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            );
          } else if (status == 'received') {
            child = SizedBox(
              width: 125,
              child: DropdownButton<String>(
                dropdownColor: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                key: ValueKey('received'),
                hint: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(125, 50),
                  ),
                  child: const Text(
                    'Respond',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                items: ['Accept', 'Decline']
                    .map((item) => DropdownMenuItem<String>(
                          value: item.toLowerCase(),
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: (String? action) {
                  if (action == 'accept') {
                    FriendService.acceptFriendRequest(
                        widget.userId, widget.currentUserId);
                  } else if (action == 'decline') {
                    FriendService.cancelRequest(
                        widget.userId, widget.currentUserId, 'declined');
                  }
                },
                underline: const SizedBox(),
                icon: const SizedBox(),
              ),
            );
          } else {
            child = ElevatedButton(
              key: ValueKey('add_friend'),
              onPressed: () => FriendService.sendFriendRequest(
                  widget.userId, widget.currentUserId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                minimumSize: const Size(125, 50),
              ),
              child: const Text(
                'Add Friend',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            );
          }
        } else {
          child = const CircularProgressIndicator(
            key: ValueKey('progress'),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: child,
        );
      },
    );
  }
}
