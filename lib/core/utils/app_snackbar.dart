import 'package:flutter/material.dart';

enum SnackBarType { success, error, info, warning }

class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // 1. Define standard styles based on type
    final (Color color, IconData icon) = switch (type) {
      SnackBarType.success => (Colors.green, Icons.check_circle_outline),
      SnackBarType.error => (Colors.redAccent, Icons.error_outline),
      SnackBarType.warning => (
          Colors.orangeAccent,
          Icons.warning_amber_rounded
        ),
      SnackBarType.info => (Colors.blue, Icons.info_outline),
    };

    // 2. Clear existing snackbars to prevent stacking
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // 3. Show the custom snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
