import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VolumeNavigationWrapper extends StatelessWidget {
  final Widget child;
  final FocusNode focusNode;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;

  const VolumeNavigationWrapper({
    super.key,
    required this.child,
    required this.focusNode,
    required this.onVolumeUp,
    required this.onVolumeDown,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
            onVolumeDown();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
            onVolumeUp();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
