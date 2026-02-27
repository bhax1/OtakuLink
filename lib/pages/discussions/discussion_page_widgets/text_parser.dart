import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'spoiler_widget.dart';

class TextParser {
  static final RegExp _mentionRegex = RegExp(r"\@\w+");
  static final RegExp _spoilerRegex = RegExp(r'>!(.*?)!<', dotAll: true);

  // Added BuildContext so we can use Theme.of(context)
  static TextSpan buildMentionsSpan(
      BuildContext context, String text, Function(String) onMentionTap) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    List<InlineSpan> spans = [];

    text.splitMapJoin(
      _mentionRegex,
      onMatch: (Match match) {
        final mention = match.group(0)!;
        spans.add(
          TextSpan(
            text: mention,
            style: TextStyle(
                color: isDarkMode
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () => onMentionTap(mention),
          ),
        );
        return mention;
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(
            text: nonMatch,
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                height: 1.5)));
        return nonMatch;
      },
    );
    return TextSpan(children: spans);
  }

  // Added BuildContext requirement
  static Widget buildParsedRichText(
      BuildContext context, String text, Function(String) onMentionTap) {
    final matches = _spoilerRegex.allMatches(text);

    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        String preText = text.substring(lastMatchEnd, match.start);
        spans.add(buildMentionsSpan(context, preText, onMentionTap));
      }

      String hiddenContent = match.group(1) ?? "";
      if (hiddenContent.trim().isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SpoilerWidget(
              content: hiddenContent,
              // Pass the context into the callback
              mentionParser: (ctx, t) =>
                  buildMentionsSpan(ctx, t, onMentionTap),
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      String remaining = text.substring(lastMatchEnd);
      spans.add(buildMentionsSpan(context, remaining, onMentionTap));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(height: 1.5),
    );
  }
}
