import 'package:flutter/material.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/follow_service.dart';

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
  
  // Reusable Pill Style
  ButtonStyle get _pillStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.blue, // Primary color
      foregroundColor: Colors.white, // Text color
      elevation: 0, // Flat look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Pill shape
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Compact padding
    );
  }

  // Outline/Active Style (for "Following" state)
  ButtonStyle get _pillOutlineStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white, 
      foregroundColor: Colors.blue, 
      elevation: 0,
      side: const BorderSide(color: Colors.blue), // Border instead of fill
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: FollowService.getFollowStatusStream(
          widget.currentUserId, widget.userId),
      builder: (context, snapshot) {
        Widget child;

        // --- LOADING ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          child = ElevatedButton(
            key: const ValueKey('loading'),
            onPressed: null,
            style: _pillStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.grey[300])),
            child: const SizedBox(
              width: 16, 
              height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            ),
          );
        } 
        // --- ERROR ---
        else if (snapshot.hasError) {
          child = const Icon(Icons.error_outline, color: Colors.red);
        } 
        // --- DATA ---
        else if (snapshot.hasData) {
          String followStatus = snapshot.data!;
          
          if (followStatus == 'following') {
            // "Following" State -> Popup Menu
            child = PopupMenuButton<String>(
              key: const ValueKey('following'),
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (String action) {
                if (action == 'unfollow') {
                  FollowService.unfollowUser(widget.currentUserId, widget.userId);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'unfollow',
                  child: Text('Unfollow', style: TextStyle(color: Colors.red)),
                ),
              ],
              // This child acts as the button trigger
              child: IgnorePointer(
                child: ElevatedButton(
                  onPressed: () {}, 
                  style: _pillOutlineStyle, // Use outline style for active state
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Following'),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ),
            );
          } else {
            // "Follow" State -> Simple Button
            child = ElevatedButton.icon(
              key: const ValueKey('follow'),
              onPressed: () => FollowService.followUser(widget.currentUserId, widget.userId),
              style: _pillStyle,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Follow'),
            );
          }
        } else {
          child = const SizedBox.shrink();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }
}