import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/main.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMine;
  final String friendProfilePic;
  final String friendName;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMine,
    required this.friendProfilePic,
    required this.friendName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMine)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: CircleAvatar(
              backgroundImage: friendProfilePic.isNotEmpty
                  ? CachedNetworkImageProvider(friendProfilePic)
                  : null,
              child: friendProfilePic.isEmpty
                  ? Text(
                      friendName.isNotEmpty
                          ? friendName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    )
                  : null,
              backgroundColor: friendProfilePic.isEmpty
                  ? Colors.blueGrey
                  : Colors.transparent,
            ),
          ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: Container(
              decoration: BoxDecoration(
                color: isMine ? primaryColor : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                message,
                style: TextStyle(
                  color: isMine ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                softWrap: true,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
