import 'package:flutter/material.dart';
import 'package:otakulink/pages/profile/widgets_viewprofile/friend_service.dart';

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

  // Primary Action Style (Add Friend)
  ButtonStyle get _actionStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.blue, 
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }

  // Secondary/Active Style (Friends/Sent)
  ButtonStyle get _activeStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[200], 
      foregroundColor: Colors.black87,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: FriendService.getFriendStatusStream(widget.userId, widget.currentUserId),
      builder: (context, snapshot) {
        Widget child;

        // --- LOADING ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          child = ElevatedButton(
            key: const ValueKey('loading'),
            onPressed: null,
            style: _activeStyle,
            child: const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)
            ),
          );
        } 
        // --- ERROR ---
        else if (snapshot.hasError) {
          child = const Icon(Icons.error_outline, color: Colors.red);
        } 
        // --- DATA ---
        else if (snapshot.hasData) {
          final status = snapshot.data;

          if (status == 'friends') {
            // "Friends" -> Popup Menu
            child = PopupMenuButton<String>(
              key: const ValueKey('friends'),
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (String action) async {
                if (action == 'unfriend') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Unfriend'),
                        content: const Text('Are you sure you want to unfriend this user?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Unfriend', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    FriendService.unfriend(widget.userId, widget.currentUserId);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'unfriend',
                  child: Text('Unfriend', style: TextStyle(color: Colors.red)),
                ),
              ],
              child: IgnorePointer(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: _activeStyle.copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.green.withOpacity(0.1)),
                    foregroundColor: WidgetStateProperty.all(Colors.green[700]),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Friends'),
                ),
              ),
            );
          } else if (status == 'sent') {
            // "Sent" -> Cancel Button
            child = ElevatedButton.icon(
              key: const ValueKey('sent'),
              onPressed: () => FriendService.cancelRequest(
                  widget.userId, widget.currentUserId, 'cancelled'),
              style: _activeStyle, // Grey out for sent state
              icon: const Icon(Icons.access_time, size: 18),
              label: const Text('Sent'),
            );
          } else if (status == 'received') {
            // "Respond" -> Popup Menu
            child = PopupMenuButton<String>(
              key: const ValueKey('received'),
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (String action) {
                if (action == 'accept') {
                  FriendService.acceptFriendRequest(widget.userId, widget.currentUserId);
                } else if (action == 'decline') {
                  FriendService.cancelRequest(widget.userId, widget.currentUserId, 'declined');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'accept',
                  child: Text('Accept Request', style: TextStyle(color: Colors.green)),
                ),
                const PopupMenuItem(
                  value: 'decline',
                  child: Text('Decline Request', style: TextStyle(color: Colors.red)),
                ),
              ],
              child: IgnorePointer(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: _actionStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.blueGrey)),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Respond'),
                ),
              ),
            );
          } else {
            // "Add Friend" -> Standard Button
            child = ElevatedButton.icon(
              key: const ValueKey('add_friend'),
              onPressed: () => FriendService.sendFriendRequest(widget.userId, widget.currentUserId),
              style: _actionStyle,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add Friend'),
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