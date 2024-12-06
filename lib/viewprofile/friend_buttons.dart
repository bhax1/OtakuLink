import 'package:flutter/material.dart';
import 'package:otakulink/viewprofile/friend_service.dart';

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 35),
            ),
            child: const Text('Loading...'),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.hasData) {
          final status = snapshot.data;
          if (status == 'friends') {
            return DropdownButton<String>(
              key: ValueKey('friends'), // Unique key for this state
              hint: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 35),
                ),
                child: Text(
                  'Friends',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              items: ['Unfriend', 'Cancel']
                  .map((item) => DropdownMenuItem<String>(
                        value: item.toLowerCase(),
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: (String? action) {
                if (action == 'accept') ;
                if (action == 'decline') ;
              },
              underline: const SizedBox(),
            );
          } else if (status == 'sent') {
            return ElevatedButton(
              key: ValueKey('sent'),
              onPressed: () => FriendService.cancelRequest(
                  widget.userId, widget.currentUserId, 'cancelled'),
              child: const Text('Cancel Request'),
            );
          } else if (status == 'received') {
            return DropdownButton<String>(
              key: ValueKey('received'),
              hint: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 35),
                ),
                child: Text(
                  'Respond',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              items: ['Accept', 'Decline']
                  .map((item) => DropdownMenuItem<String>(
                        value: item.toLowerCase(),
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: (String? action) {
                if (action == 'accept')
                  FriendService.acceptFriendRequest(
                      widget.userId, widget.currentUserId);
                if (action == 'decline')
                  FriendService.cancelRequest(
                      widget.userId, widget.currentUserId, 'declined');
              },
              underline: const SizedBox(),
            );
          } else {
            return ElevatedButton(
              key: ValueKey('add_friend'),
              onPressed: () => FriendService.sendFriendRequest(
                  widget.userId, widget.currentUserId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 35),
              ),
              child: const Text(
                'Add Friend',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }
        }
        return const CircularProgressIndicator(); // Fallback in case of unexpected state
      },
    );
  }
}
