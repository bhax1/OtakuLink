import 'package:flutter/material.dart';

class ReactionBubble extends StatefulWidget {
  final List<String> emojis;
  final Function(String) onEmojiSelected;
  final String? currentReaction;

  const ReactionBubble({
    Key? key, 
    required this.emojis, 
    required this.onEmojiSelected, 
    this.currentReaction
  }) : super(key: key);

  @override
  State<ReactionBubble> createState() => _ReactionBubbleState();
}

class _ReactionBubbleState extends State<ReactionBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _hoveredEmoji; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 400)
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent, 
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.emojis.length, (index) {
            final emoji = widget.emojis[index];
            final isSelected = emoji == widget.currentReaction;
            final animation = CurvedAnimation(
              parent: _controller, 
              curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutBack)
            );

            return ScaleTransition(
              scale: animation,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _hoveredEmoji = emoji),
                onTapUp: (_) => setState(() => _hoveredEmoji = null),
                onTapCancel: () => setState(() => _hoveredEmoji = null),
                onTap: () => widget.onEmojiSelected(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  transform: Matrix4.identity()
                    ..scale(_hoveredEmoji == emoji ? 1.5 : (isSelected ? 1.2 : 1.0)),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.only(bottom: 4), 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24, height: 1.0)),
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 2), 
                          width: 4, 
                          height: 4, 
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent, 
                            shape: BoxShape.circle
                          )
                        )
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}