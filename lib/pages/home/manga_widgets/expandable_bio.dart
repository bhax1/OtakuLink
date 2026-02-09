import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:otakulink/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpandableBio extends StatelessWidget {
  final String rawBio;
  final bool isStaff;
  final Function(int) onCharacterTap;

  const ExpandableBio({
    super.key,
    required this.rawBio,
    required this.isStaff,
    required this.onCharacterTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1. PRE-PROCESS: Fix AniList's messy Markdown formatting
    String processedBio = rawBio
    // Fix the "No Spacing" issue: __Label:__Value -> **Label**: Value
    .replaceAllMapped(RegExp(r'__(.*?)__:(?!\s)'), (match) {
      return '**${match.group(1)}**: '; 
    })
    
    // Fix the case where the value is already bolded but touching: __Label__Value
    .replaceAllMapped(RegExp(r'__(.*?)__(?!\s)'), (match) {
      return '**${match.group(1)}** ';
    })

    // Convert all other __ to ** for better compatibility
    .replaceAll('__', '**')

    // Ensure there are double newlines before labels to trigger a block
    .replaceAll(RegExp(r'(\n|^)\*\*'), '\n\n**')

    // Isolate spoilers so they don't "bleed" into the text lines
    .replaceAll('~!', '\n\n~!')
    .replaceAll('!~', '!~\n\n')
    
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

    final RegExp spoilerRegex = RegExp(r'~!(.*?)!~', dotAll: true);
    List<Widget> bioWidgets = [];
    int lastMatchEnd = 0;

    // --- HANDLE LINK FUNCTION ---
    Future<void> handleLink(String? href) async {
      if (href == null) return;

      // 1. Handle Internal App Navigation (Characters)
      if (href.contains('anilist.co/character/')) {
        final uri = Uri.parse(href);
        final segments = uri.pathSegments;
        if (segments.length >= 2) {
          final charId = int.tryParse(segments[1]);
          if (charId != null) {
            onCharacterTap(charId);
            return; // Stop here if it was an internal link
          }
        }
      }

      // 2. Handle External Links (Twitter, Pixiv, Personal Sites)
      try {
        final uri = Uri.parse(href);
        if (await canLaunchUrl(uri)) {
          // LaunchMode.externalApplication forces it to open in Twitter/Browser/etc.
          await launchUrl(uri, mode: LaunchMode.externalApplication); 
        } else {
          debugPrint("Could not launch url: $href");
        }
      } catch (e) {
        debugPrint("Error launching url: $e");
      }
    }
    // ----------------------------------------

    final allMatches = spoilerRegex.allMatches(processedBio).toList();

    for (var match in allMatches) {
      // Preceding text chunk
      String precedingText = processedBio.substring(lastMatchEnd, match.start);
      if (precedingText.isNotEmpty) {
        bioWidgets.add(
          MarkdownBody(
            data: precedingText, // DO NOT TRIM - preserves newlines
            onTapLink: (text, href, title) => handleLink(href),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF495057)),
              strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              a: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              blockSpacing: 12,
            ),
          ),
        );
      }

      // Spoiler block
      bioWidgets.add(
        IndividualSpoiler(
          content: match.group(1) ?? "",
          onTapLink: handleLink,
        ),
      );

      lastMatchEnd = match.end;
    }

    // Remaining text after last spoiler
    if (lastMatchEnd < processedBio.length) {
      String remainingText = processedBio.substring(lastMatchEnd);
      if (remainingText.trim().isNotEmpty) {
        bioWidgets.add(
          MarkdownBody(
            data: remainingText,
            onTapLink: (text, href, title) => handleLink(href),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF495057)),
              strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              a: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              blockSpacing: 12,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isStaff ? "Background" : "Biography",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bioWidgets,
          ),
        ),
      ],
    );
  }
}

class IndividualSpoiler extends StatefulWidget {
  final String content;
  final Function(String?) onTapLink;

  const IndividualSpoiler({super.key, required this.content, required this.onTapLink});

  @override
  State<IndividualSpoiler> createState() => _IndividualSpoilerState();
}

class _IndividualSpoilerState extends State<IndividualSpoiler> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (!_isRevealed) setState(() => _isRevealed = true);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isRevealed ? AppColors.primary.withOpacity(0.05) : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          border: _isRevealed ? Border.all(color: AppColors.primary.withOpacity(0.2)) : null,
        ),
        child: _isRevealed
            ? MarkdownBody(
                data: widget.content,
                onTapLink: (text, href, title) => widget.onTapLink(href),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, color: Colors.black87),
                  a: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.black54),
                  SizedBox(width: 8),
                  Text("Tap to reveal spoiler", style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}