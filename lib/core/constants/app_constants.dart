enum PlatformType {
  tiktok,
  youtube,
  instagram,
  facebook,
  unknown;

  String get displayName {
    switch (this) {
      case PlatformType.tiktok:
        return 'TikTok';
      case PlatformType.youtube:
        return 'YouTube';
      case PlatformType.instagram:
        return 'Instagram';
      case PlatformType.facebook:
        return 'Facebook';
      case PlatformType.unknown:
        return 'Desconocido';
    }
  }

  String get iconAsset {
    switch (this) {
      case PlatformType.tiktok:
        return 'tiktok';
      case PlatformType.youtube:
        return 'youtube';
      case PlatformType.instagram:
        return 'instagram';
      case PlatformType.facebook:
        return 'facebook';
      case PlatformType.unknown:
        return 'unknown';
    }
  }
}

class AppConstants {
  static const String defaultCategory = 'General';

  static const int maxTitleLength = 200;
  static const int maxNotesLength = 1000;
  static const int maxCategoryNameLength = 50;

  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double chipBorderRadius = 20.0;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration syncInterval = Duration(minutes: 5);

  static const List<String> supportedDomains = [
    'tiktok.com',
    'youtube.com',
    'youtu.be',
    'instagram.com',
    'facebook.com',
    'fb.watch',
  ];
}
