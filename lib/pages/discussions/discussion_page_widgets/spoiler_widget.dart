import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpoilerWidget extends StatefulWidget {
  final String content;
  final TextSpan Function(BuildContext, String) mentionParser;

  const SpoilerWidget(
      {Key? key, required this.content, required this.mentionParser})
      : super(key: key);

  @override
  _SpoilerWidgetState createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<SpoilerWidget> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          // Use theme containers to switch properly in dark mode
          color: _isRevealed
              ? theme.colorScheme.secondaryContainer.withOpacity(0.3)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isRevealed
                ? Colors.transparent
                : theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: _isRevealed ? 1.0 : 0.0,
              // Pass context down so mentions render in correct theme color
              child: Text.rich(widget.mentionParser(context, widget.content)),
            ),
            if (!_isRevealed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    "SPOILER",
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
