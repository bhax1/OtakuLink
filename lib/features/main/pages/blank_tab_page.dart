import 'package:flutter/material.dart';

class BlankTabPage extends StatelessWidget {
  final String title;

  const BlankTabPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$title Page (Under Construction)',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
