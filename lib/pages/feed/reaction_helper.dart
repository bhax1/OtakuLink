import 'package:flutter/material.dart';

class ReactionTypes {
  static const String like = 'like';
  static const String love = 'love';
  static const String haha = 'haha';
  static const String wow = 'wow';
  static const String sad = 'sad';
  static const String angry = 'angry';

  // Return Emoji String instead of IconData
  static String getEmoji(String type) {
    switch (type) {
      case like: return '👍';
      case love: return '❤️';
      case haha: return '😂';
      case wow: return '😮';
      case sad: return '😢';
      case angry: return '😡';
      default: return '👍';
    }
  }

  // Helper for the text label (e.g. "Love", "Haha")
  static String getName(String type) {
    switch (type) {
      case like: return 'Like';
      case love: return 'Love';
      case haha: return 'Haha';
      case wow: return 'Wow';
      case sad: return 'Sad';
      case angry: return 'Angry';
      default: return 'Like';
    }
  }

  // Keep colors for the text label
  static Color getColor(String type) {
    switch (type) {
      case like: return Colors.blue;
      case love: return const Color(0xFFED4956); // Instagram Red
      case haha: return Colors.orange;
      case wow: return Colors.orange;
      case sad: return Colors.orange;
      case angry: return Colors.deepOrange;
      default: return Colors.grey;
    }
  }
}