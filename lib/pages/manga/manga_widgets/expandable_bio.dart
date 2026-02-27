import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

// --- OPTIMIZATION: Intermediate Data Structure ---
class _BioChunk {
  final String text;
  final bool isSpoiler;
  _BioChunk(this.text, this.isSpoiler);
}

class ExpandableBio extends StatefulWidget {
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
  State<ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<ExpandableBio> {
  // --- OPTIMIZATION: O(1) Pre-compiled Regexes ---
  static final RegExp _boldColonRegex = RegExp(r'__(.*?)__:(?!\s)');
  static final RegExp _boldRegex = RegExp(r'__(.*?)__(?!\s)');
  static final RegExp _newlineBoldRegex = RegExp(r'(\n|^)\*\*');
  static final RegExp _tripleNewlineRegex = RegExp(r'\n{3,}');
  static final RegExp _spoilerRegex = RegExp(r'~!(.*?)!~', dotAll: true);

  final List<_BioChunk> _chunks = [];

  @override
  void initState() {
    super.initState();
    _parseBioData(); // Parse once on load
  }

  @override
  void didUpdateWidget(covariant ExpandableBio oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-parse if the actual bio text changes
    if (oldWidget.rawBio != widget.rawBio) {
      _parseBioData();
    }
  }

  // --- OPTIMIZATION: CPU-Heavy string manipulation isolated from the UI thread ---
  void _parseBioData() {
    _chunks.clear();

    String processedBio = widget.rawBio
        .replaceAllMapped(_boldColonRegex, (match) => '**${match.group(1)}**: ')
        .replaceAllMapped(_boldRegex, (match) => '**${match.group(1)}** ')
        .replaceAll('__', '**')
        .replaceAll(_newlineBoldRegex, '\n\n**')
        .replaceAll('~!', '\n\n~!')
        .replaceAll('!~', '!~\n\n')
        .replaceAll(_tripleNewlineRegex, '\n\n')
        .trim();

    int lastMatchEnd = 0;
    final allMatches = _spoilerRegex.allMatches(processedBio);

    for (var match in allMatches) {
      String precedingText = processedBio.substring(lastMatchEnd, match.start);
      if (precedingText.isNotEmpty) {
        _chunks.add(_BioChunk(precedingText, false));
      }
      _chunks.add(_BioChunk(match.group(1) ?? "", true));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < processedBio.length) {
      String remainingText = processedBio.substring(lastMatchEnd);
      if (remainingText.trim().isNotEmpty) {
        _chunks.add(_BioChunk(remainingText, false));
      }
    }
  }

  Future<void> _handleLink(String? href) async {
    if (href == null) return;

    if (href.contains('anilist.co/character/')) {
      final uri = Uri.parse(href);
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        final charId = int.tryParse(segments[1]);
        if (charId != null) {
          widget.onCharacterTap(charId);
          return;
        }
      }
    }

    try {
      final uri = Uri.parse(href);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch url: $href");
      }
    } catch (e) {
      debugPrint("Error launching url: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final markdownStyle = MarkdownStyleSheet(
      p: textTheme.bodyMedium?.copyWith(height: 1.6),
      strong: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      a: TextStyle(
          color: isDark ? colorScheme.secondary : colorScheme.primary,
          fontWeight: FontWeight.bold),
      blockSpacing: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isStaff ? "Background" : "Biography",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
            border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
          ),

          // --- OPTIMIZATION: Light, O(1) mapping during build ---
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _chunks.map((chunk) {
              if (chunk.isSpoiler) {
                return IndividualSpoiler(
                  content: chunk.text,
                  onTapLink: _handleLink,
                );
              } else {
                return MarkdownBody(
                  data: chunk.text,
                  onTapLink: (text, href, title) => _handleLink(href),
                  styleSheet: markdownStyle,
                );
              }
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class IndividualSpoiler extends StatefulWidget {
  final String content;
  final Function(String?) onTapLink;

  const IndividualSpoiler({
    super.key,
    required this.content,
    required this.onTapLink,
  });

  @override
  State<IndividualSpoiler> createState() => _IndividualSpoilerState();
}

class _IndividualSpoilerState extends State<IndividualSpoiler> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        if (!_isRevealed) setState(() => _isRevealed = true);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isRevealed
              ? colorScheme.primaryContainer.withOpacity(0.2)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: _isRevealed
              ? Border.all(
                  color: isDark
                      ? colorScheme.secondary.withOpacity(0.3)
                      : colorScheme.primary.withOpacity(0.3))
              : null,
        ),
        child: _isRevealed
            ? MarkdownBody(
                data: widget.content,
                onTapLink: (text, href, title) => widget.onTapLink(href),
                styleSheet: MarkdownStyleSheet(
                  p: textTheme.bodyMedium,
                  a: TextStyle(
                      color:
                          isDark ? colorScheme.secondary : colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    "Tap to reveal spoiler",
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
