import 'package:flutter/material.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/widgets_viewprofile/follow_service.dart';

class FollowButtons extends StatefulWidget {
  final String userId;
  final String? currentUserId;

  const FollowButtons(
      {Key? key, required this.userId, required this.currentUserId})
      : super(key: key);

  @override
  _FollowButtonsState createState() => _FollowButtonsState();
}

class _FollowButtonsState extends State<FollowButtons> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: FollowService.getFollowStatusStream(
          widget.currentUserId, widget.userId),
      builder: (context, snapshot) {
        Widget child;

        // Handle waiting state
        if (snapshot.connectionState == ConnectionState.waiting) {
          child = ElevatedButton(
            key: const ValueKey('loading'),
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              minimumSize: const Size(120, 50), // Fixed size
            ),
            child: const Text('Loading...'),
          );
        } 
        // Handle errors
        else if (snapshot.hasError) {
          child = Center(
            key: const ValueKey('error'),
            child: Text('Error: ${snapshot.error}'),
          );
        } 
        // Handle data received
        else if (snapshot.hasData) {
          String followStatus = snapshot.data!;
          if (followStatus == 'following') {
            child = SizedBox(
              width: 120,
              child: DropdownButton<String>(
                dropdownColor: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                key: const ValueKey('following'),
                hint: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(120, 50), // Fixed size
                  ),
                  child: const Text(
                    'Following',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                items: ['Unfollow', 'Cancel']
                    .map((item) => DropdownMenuItem<String>(
                          value: item.toLowerCase(),
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: (String? action) {
                  if (action == 'unfollow') {
                    FollowService.unfollowUser(
                        widget.currentUserId, widget.userId);
                  }
                },
                underline: const SizedBox(),
                icon: const SizedBox(),
              ),
            );
          } else {
            child = ElevatedButton(
              key: const ValueKey('follow'),
              onPressed: () => FollowService.followUser(
                  widget.currentUserId, widget.userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(120, 48),
              ),
              child: const Text(
                'Follow',
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
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}
