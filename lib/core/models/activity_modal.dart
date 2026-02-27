import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActivityItem {
  final String id;
  final String mangaId;
  final String title;
  final String action;
  final String status;
  final double lastChapterRead;
  final DateTime updatedAt;

  ActivityItem({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.action,
    required this.status,
    required this.lastChapterRead,
    required this.updatedAt,
  });

  factory ActivityItem.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Derive the status to determine the action text
    final String status = data['status'] ?? 'Reading';
    final double lastCh = (data['lastChapterRead'] ?? 0).toDouble();

    // Create a dynamic action string based on the data available
    String derivedAction = status;
    if (lastCh > 0) {
      // Clean up .0 from doubles (e.g., 42.0 -> 42)
      final String chStr = lastCh.toString().replaceAll('.0', '');
      derivedAction = "Read Chapter $chStr • $status";
    }

    return ActivityItem(
      id: doc.id,
      mangaId: data['mangaId']?.toString() ?? doc.id,
      title: data['title'] ?? 'Unknown Manga',
      action: derivedAction,
      status: status,
      lastChapterRead: lastCh,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  IconData get icon {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'Dropped':
        return Icons.delete_forever;
      case 'Plan to Read':
        return Icons.bookmark;
      case 'On Hold':
        return Icons.pause_circle_filled;
      case 'Reading':
      default:
        // If they have read a chapter, show book, else show generic play
        return lastChapterRead > 0 ? Icons.menu_book : Icons.play_circle_filled;
    }
  }

  Color get color {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Dropped':
        return Colors.red;
      case 'Plan to Read':
        return Colors.purpleAccent;
      case 'On Hold':
        return Colors.orange;
      case 'Reading':
      default:
        return Colors.blueAccent;
    }
  }
}
