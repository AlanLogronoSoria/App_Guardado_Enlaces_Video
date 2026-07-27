import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/models/link.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class LinkCard extends StatefulWidget {
  final LinkModel link;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const LinkCard({
    super.key,
    required this.link,
    this.onTap,
    this.onFavoriteToggle,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  State<LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends State<LinkCard> {
  bool _isHovering = false;

  void _shareLink() {
    Share.share('${widget.link.title}\n${widget.link.url}');
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.link.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Enlace copiado'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final colorScheme = Theme.of(context).colorScheme;
    final platform = PlatformType.values.firstWhere(
      (p) => p.name == link.platform,
      orElse: () => PlatformType.unknown,
    );
    final platformColor = AppTheme.platformColor(platform);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.isSelectionMode
          ? null
          : () {
              setState(() => _isHovering = true);
              widget.onLongPress?.call();
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) setState(() => _isHovering = false);
              });
            },
      child: Stack(
        children: [
          AnimatedScale(
            scale: _isHovering ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: colorScheme.surfaceContainerLow,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: link.thumbnail != null
                            ? CachedNetworkImage(
                                imageUrl: link.thumbnail!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _buildThumbnailPlaceholder(platformColor),
                                errorWidget: (_, __, ___) =>
                                    _buildThumbnailPlaceholder(platformColor),
                              )
                            : _buildThumbnailPlaceholder(platformColor),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 50,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withAlpha(70),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_platformIcon(platform),
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                platform.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.onFavoriteToggle != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: widget.onFavoriteToggle,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  link.favorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                  color: link.favorite
                                      ? Colors.red
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!widget.isSelectionMode)
                        Positioned(
                          top: widget.onFavoriteToggle != null ? 48 : 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => _showActionsMenu(context),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_horiz,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          link.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.folder_rounded,
                                size: 13, color: colorScheme.primary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                link.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isSelectionMode)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? colorScheme.primary
                      : Colors.black.withAlpha(120),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  void _showActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Compartir enlace'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareLink();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copiar enlace'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyLink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(Color platformColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            platformColor.withAlpha(80),
            platformColor.withAlpha(20),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.play_circle_rounded,
            size: 42, color: platformColor.withAlpha(120)),
      ),
    );
  }

  IconData _platformIcon(PlatformType platform) {
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
