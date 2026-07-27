import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/platform_detector.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/widgets/platform_icon.dart';

class AddLinkScreen extends ConsumerStatefulWidget {
  final String? initialUrl;

  const AddLinkScreen({super.key, this.initialUrl});

  @override
  ConsumerState<AddLinkScreen> createState() => _AddLinkScreenState();
}

class _AddLinkScreenState extends ConsumerState<AddLinkScreen> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedCategory;
  PlatformType _detectedPlatform = PlatformType.unknown;
  String? _thumbnailUrl;
  bool _isLoadingMetadata = false;
  bool _isSaving = false;
  bool _showAiSuggestion = false;
  String? _aiCategory;
  String? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _processUrl(widget.initialUrl!);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _processUrl(String url) async {
    final platform = PlatformDetector.detect(url);

    setState(() {
      _detectedPlatform = platform;
      _isLoadingMetadata = true;
    });

    if (platform == PlatformType.unknown) {
      setState(() {
        _isLoadingMetadata = false;
      });
      return;
    }

    final metadataService = ref.read(metadataServiceProvider);
    final metadata = await metadataService.fetchMetadata(url, platform);

    setState(() {
      _isLoadingMetadata = false;
      if (_titleController.text.isEmpty) {
        _titleController.text = metadata.title ?? '';
      }
      _thumbnailUrl = metadata.thumbnail;
    });

    _requestAiSuggestion();
  }

  Future<void> _requestAiSuggestion() async {
    final title = _titleController.text;
    if (title.isEmpty) return;

    final openaiService = ref.read(openaiServiceProvider);
    final result = await openaiService.suggestCategory(title);

    if (result.category != null && mounted) {
      setState(() {
        _showAiSuggestion = true;
        _aiCategory = result.category;
        _aiSuggestion = result.suggestion;
      });
    }
  }

  Future<void> _saveLink() async {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    final title = _titleController.text.trim();
    final platform = _detectedPlatform.name;
    final category = _selectedCategory ?? AppConstants.defaultCategory;

    if (url.isEmpty || title.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final categoryRepo = ref.read(categoryRepositoryProvider);
      await categoryRepo.ensureCategory(category);

      final linkRepo = ref.read(linkRepositoryProvider);
      await linkRepo.saveLink(
        url: url,
        platform: platform,
        title: title,
        thumbnail: _thumbnailUrl,
        category: category,
      );

      ref.invalidate(allLinksProvider);
      ref.invalidate(allCategoriesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Video guardado'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar enlace'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveLink,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_thumbnailUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: _thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) =>
                          _buildThumbnailPlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (_detectedPlatform != PlatformType.unknown) ...[
                _buildThumbnailPlaceholder(),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    tooltip: 'Detectar plataforma',
                    onPressed: () => _processUrl(_urlController.text),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa una URL';
                  }
                  final url = value.trim();
                  if (!url.startsWith('http://') &&
                      !url.startsWith('https://')) {
                    return 'URL inválida';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length > 20) {
                    final platform = PlatformDetector.detect(value);
                    if (platform != _detectedPlatform) {
                      _processUrl(value);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_detectedPlatform != PlatformType.unknown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      PlatformIcon(
                        platform: _detectedPlatform,
                        size: 20,
                        showLabel: true,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Detectado',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoadingMetadata)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              TextFormField(
                controller: _titleController,
                maxLength: AppConstants.maxTitleLength,
                decoration: const InputDecoration(
                  labelText: 'Título',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox(),
                data: (categories) {
                  final items = categories
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(c.name),
                          ))
                      .toList();

                  return DropdownButtonFormField<String>(
                    initialValue: items.any((i) => i.value == _selectedCategory)
                        ? _selectedCategory
                        : items.isNotEmpty
                            ? items.first.value
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                    ),
                    items: items,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  );
                },
              ),
              if (_showAiSuggestion && _aiCategory != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colorScheme.tertiary.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 20, color: colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            'Sugerencia IA',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Categoría sugerida: "$_aiCategory"',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (_aiSuggestion != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _aiSuggestion!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = _aiCategory;
                                  _showAiSuggestion = false;
                                });
                              },
                              child: const Text('Usar sugerencia'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(
                                  () => _showAiSuggestion = false);
                            },
                            child: const Text('Ignorar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveLink,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar video'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 48,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withAlpha(100),
          ),
        ),
      ),
    );
  }
}
