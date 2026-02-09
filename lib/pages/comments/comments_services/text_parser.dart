import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/theme.dart';

import '../comments_page_widgets/spoiler_widget.dart';

class TextParser {
  static TextSpan buildMentionsSpan(String text, Function(String) onMentionTap) {
    List<InlineSpan> spans = [];
    text.splitMapJoin(
      RegExp(r"\@\w+"),
      onMatch: (Match match) {
        final mention = match.group(0)!;
        spans.add(
          TextSpan(
            text: mention,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => onMentionTap(mention),
          ),
        );
        return mention;
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5)));
        return nonMatch;
      },
    );
    return TextSpan(children: spans);
  }

  static Widget buildParsedRichText(String text, Function(String) onMentionTap) {
    final spoilerRegex = RegExp(r'>!(.*?)!<', dotAll: true);
    final matches = spoilerRegex.allMatches(text);

    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        String preText = text.substring(lastMatchEnd, match.start);
        spans.add(buildMentionsSpan(preText, onMentionTap));
      }

      String hiddenContent = match.group(1) ?? "";
      if (hiddenContent.trim().isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SpoilerWidget(
              content: hiddenContent,
              mentionParser: (t) => buildMentionsSpan(t, onMentionTap),
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      String remaining = text.substring(lastMatchEnd);
      spans.add(buildMentionsSpan(remaining, onMentionTap));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(height: 1.5),
    );
  }
}