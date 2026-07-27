import '../constants/app_constants.dart';

class PlatformDetector {
  static PlatformType detect(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('tiktok.com')) {
      return PlatformType.tiktok;
    }
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return PlatformType.youtube;
    }
    if (lowerUrl.contains('instagram.com')) {
      return PlatformType.instagram;
    }
    if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.watch')) {
      return PlatformType.facebook;
    }

    return PlatformType.unknown;
  }

  static bool isValidSocialUrl(String url) {
    final platform = detect(url);
    return platform != PlatformType.unknown;
  }
}
