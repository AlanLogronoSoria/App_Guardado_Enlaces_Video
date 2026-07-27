import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/platform_detector.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/widgets/platform_icon.dart';

class QuickSaveSheet extends ConsumerStatefulWidget {
  final String url;

  const QuickSaveSheet({super.key, required this.url});

  @override
  ConsumerState<QuickSaveSheet> createState() => _QuickSaveSheetState();
}

class _QuickSaveSheetState extends ConsumerState<QuickSaveSheet>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  PlatformType _platform = PlatformType.unknown;
  String _title = '';
  String? _thumbnail;
  String _category = AppConstants.defaultCategory;
  bool _aiLoading = false;
  bool _aiDone = false;
  bool _categoryLocked = false;
  bool _saving = false;

  late AnimationController _entryController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryController.forward();
    _initData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final platform = PlatformDetector.detect(widget.url);
    setState(() => _platform = platform);

    if (platform == PlatformType.unknown) {
      _title = '';
      setState(() => _loading = false);
      return;
    }

    final metadataFuture = _fetchMetadata();

    _classifyCategory();

    await metadataFuture;

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMetadata() async {
    final metadataService = ref.read(metadataServiceProvider);
    try {
      final metadata =
          await metadataService.fetchMetadata(widget.url, _platform);
      if (mounted) {
        setState(() {
          _title = metadata.title ?? 'Video de ${_platform.displayName}';
          _thumbnail = metadata.thumbnail;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _title = 'Video de ${_platform.displayName}';
        });
      }
    }
  }

  Future<void> _classifyCategory() async {
    final title = _title;
    if (title.isEmpty || title.startsWith('Video de')) return;

    final categoriesAsync = ref.read(allCategoriesProvider);
    List<String> existingCategories;

    final asyncData = categoriesAsync;
    if (asyncData is AsyncData) {
      existingCategories = asyncData.requireValue.map((c) => c.name).toList();
    } else {
      try {
        final repo = ref.read(categoryRepositoryProvider);
        final cats = await repo.getAllCategories();
        existingCategories = cats.map((c) => c.name).toList();
      } catch (_) {
        existingCategories = [];
      }
    }

    if (existingCategories.isEmpty) return;

    setState(() => _aiLoading = true);

    final openaiService = ref.read(openaiServiceProvider);
    try {
      final result = await openaiService.classifyWithCategories(
        title,
        existingCategories,
      );

      if (!mounted) return;

      final suggestedCategory = result.category;

      if (suggestedCategory != null && result.isHighConfidence) {
        await ref
            .read(categoryRepositoryProvider)
            .ensureCategory(suggestedCategory);

        if (mounted && !_categoryLocked) {
          setState(() {
            _category = suggestedCategory;
            _categoryLocked = true;
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _aiLoading = false;
        _aiDone = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await ref.read(categoryRepositoryProvider).ensureCategory(_category);
      await ref.read(linkRepositoryProvider).saveLink(
            url: widget.url,
            platform: _platform.name,
            title: _title,
            thumbnail: _thumbnail,
            category: _category,
            source: 'share',
          );

      ref.invalidate(allLinksProvider);
      ref.invalidate(allCategoriesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado en $_category'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al guardar'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final platformColor = AppTheme.platformColor(_platform);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * 80),
          child: Opacity(
            opacity: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: IntrinsicHeight(
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _loading
                ? _buildLoading(colorScheme)
                : _buildContent(colorScheme, platformColor),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          Text('Obteniendo información...',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, Color platformColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    height: 70,
                    child: CachedNetworkImage(
                      imageUrl: _thumbnail!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _thumbnailPlaceholder(platformColor),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 100,
                  height: 70,
                  child: _thumbnailPlaceholder(platformColor),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlatformIcon(
                        platform: _platform, size: 14, showLabel: true),
                    const SizedBox(height: 6),
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _buildCategoryRow(colorScheme),
        ),
        if (_aiLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor:
                        AlwaysStoppedAnimation(colorScheme.tertiary),
                  ),
                ),
                const SizedBox(width: 8),
                Text('IA clasificando...',
                    style: TextStyle(
                        color: colorScheme.tertiary, fontSize: 11)),
              ],
            ),
          ),
        if (_aiDone && _categoryLocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 13, color: colorScheme.tertiary),
                const SizedBox(width: 5),
                Text('Categoría asignada por IA',
                    style: TextStyle(
                        color: colorScheme.tertiary, fontSize: 11)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(ColorScheme colorScheme) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (_, __) => const SizedBox(height: 36),
      data: (categories) {
        final items = categories
            .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
            .toList();

        return DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(
            labelText: 'Categoría',
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          isDense: true,
          items: items,
          onChanged: (v) {
            if (v != null) {
              _categoryLocked = true;
              setState(() => _category = v);
            }
          },
        );
      },
    );
  }

  Widget _thumbnailPlaceholder(Color platformColor) {
    return Container(
      decoration: BoxDecoration(
        color: platformColor.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.play_circle_outline,
          size: 28, color: platformColor.withAlpha(120)),
    );
  }
}
