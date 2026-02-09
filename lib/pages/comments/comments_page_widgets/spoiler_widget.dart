import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpoilerWidget extends StatefulWidget {
  final String content;
  final TextSpan Function(String) mentionParser;

  const SpoilerWidget({
    Key? key, 
    required this.content, 
    required this.mentionParser
  }) : super(key: key);

  @override
  _SpoilerWidgetState createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<SpoilerWidget> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isRevealed = !_isRevealed);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _isRevealed ? Colors.grey[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isRevealed ? Colors.transparent : Colors.grey[400]!,
            width: 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: _isRevealed ? 1.0 : 0.0,
              child: Text.rich(widget.mentionParser(widget.content)),
            ),
            if (!_isRevealed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(
                    "SPOILER", 
                    style: TextStyle(
                      color: Colors.grey[700], 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 0.5
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}