import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class PlatformIcon extends StatelessWidget {
  final PlatformType platform;
  final double size;
  final bool showLabel;

  const PlatformIcon({
    super.key,
    required this.platform,
    this.size = 24,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.platformColor(platform);
    final icon = _getIcon();

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: color),
          const SizedBox(width: 6),
          Text(
            platform.displayName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      );
    }

    return Icon(icon, size: size, color: color);
  }

  IconData _getIcon() {
    switch (platform) {
      case PlatformType.tiktok:
        return Icons.music_note;
      case PlatformType.youtube:
        return Icons.play_circle_filled;
      case PlatformType.instagram:
        return Icons.camera_alt;
      case PlatformType.facebook:
        return Icons.people;
      case PlatformType.unknown:
        return Icons.link;
    }
  }
}
