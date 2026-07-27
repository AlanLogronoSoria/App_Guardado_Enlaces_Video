class UrlExtractor {
  static final RegExp _urlRegex = RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b[-a-zA-Z0-9()@:%_\+.~#?&\/=]*',
    caseSensitive: false,
  );

  static List<String> extractUrls(String text) {
    final matches = _urlRegex.allMatches(text);
    final urls = <String>{};

    for (final match in matches) {
      String url = match.group(0)!;
      url = url.replaceAll(RegExp(r'[.,;:!?)\]]+$'), '');
      urls.add(url);
    }

    return urls.toList();
  }

  static List<String> extractSocialUrls(String text) {
    final allUrls = extractUrls(text);
    return allUrls.where((url) {
      final lower = url.toLowerCase();
      return lower.contains('tiktok.com') ||
          lower.contains('youtube.com') ||
          lower.contains('youtu.be') ||
          lower.contains('instagram.com') ||
          lower.contains('facebook.com') ||
          lower.contains('fb.watch');
    }).toList();
  }
}
