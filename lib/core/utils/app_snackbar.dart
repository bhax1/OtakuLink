import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  static String? _lastMessage;
  static DateTime? _lastMessageTime;

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
  }) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case SnackBarType.error:
        backgroundColor = Colors.redAccent.shade700;
        icon = Icons.error;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange.shade800;
        icon = Icons.warning;
        break;
      case SnackBarType.info:
        backgroundColor = Colors.blueGrey.shade800;
        icon = Icons.info;
        break;
    }

    final now = DateTime.now();

    // Prevent duplicate messages within 3 seconds
    if (message == _lastMessage &&
        _lastMessageTime != null &&
        now.difference(_lastMessageTime!) < const Duration(seconds: 3)) {
      return;
    }

    _lastMessage = message;
    _lastMessageTime = now;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
