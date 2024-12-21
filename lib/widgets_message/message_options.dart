import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageOptions {
  static void showMessageOptions(
    BuildContext context,
    String conversationId,
    String messageId,
    String messageText,
    String senderId,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (senderId == currentUserId) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Message Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Update Message'),
                onTap: () => _updateMessage(
                    context, conversationId, messageId, messageText),
              ),
              ListTile(
                title: Text('Delete Message'),
                onTap: () => _showConfirmationDialog(context, 'Are you sure?',
                    () => _deleteMessage(context, conversationId, messageId)),
              ),
            ],
          ),
        ),
      );
    }
  }

  static void _showConfirmationDialog(
      BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Action'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.blue),
              )),
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              child: Text(
                'Confirm',
                style: TextStyle(color: Colors.red),
              )),
        ],
      ),
    );
  }

  static void _updateMessage(BuildContext context, String conversationId,
      String messageId, String currentText) {
    final _updateController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Message'),
        content: TextField(
          controller: _updateController,
          decoration: InputDecoration(hintText: 'Edit your message'),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sendUpdatedMessage(
                    conversationId, messageId, _updateController.text);
              },
              child: Text(
                'Update',
                style: TextStyle(color: Colors.blue),
              )),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              )),
        ],
      ),
    );
  }

  static Future<void> _sendUpdatedMessage(
      String conversationId, String messageId, String updatedText) async {
    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'messageText': updatedText});
    } catch (error) {
      print("Error updating message: $error");
    }
  }

  static Future<void> _deleteMessage(
      BuildContext context, String conversationId, String messageId) async {
    try {
      Navigator.of(context).pop();
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (error) {
      print("Error deleting message: $error");
    }
  }
}
