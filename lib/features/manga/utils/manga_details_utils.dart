class MangaDetailsUtils {
  static final RegExp _htmlTagRegex =
      RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);

  static String sanitizeInput(String input, int maxLength) {
    String sanitized = input.trim();
    if (sanitized.length > maxLength) {
      return sanitized.substring(0, maxLength);
    }
    return sanitized;
  }

  static bool isValidSecureUrl(String? url) {
    return url != null && url.isNotEmpty && url.startsWith('https://');
  }

  static String parseHtml(String htmlString) {
    if (htmlString.isEmpty) return "";
    String result = htmlString.replaceAll(_htmlTagRegex, '');
    result = result
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('<br>', '\n');
    return result;
  }
}
