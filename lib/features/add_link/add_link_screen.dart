import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/platform_detector.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/models/link.dart';
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
  bool _saved = false;
  String _savedTitle = '';
  bool _showAiSuggestion = false;
  String? _aiCategory;
  String? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    print('[ADD LINK] ======== initState ========');
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      print('[ADD LINK] initialUrl recibido: ${widget.initialUrl}');
      _urlController.text = widget.initialUrl!;
      print('[ADD LINK] urlController actualizado');
      print('[ADD LINK] _processUrl iniciado');
      _processUrl(widget.initialUrl!);
    } else {
      print('[ADD LINK] sin initialUrl — abriendo formulario vacío');
    }
    print('[ADD LINK] ======== initState FIN ========');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('[ADD LINK] didChangeDependencies');
  }

  @override
  void didUpdateWidget(covariant AddLinkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[ADD LINK] didUpdateWidget: initialUrl old=${oldWidget.initialUrl} new=${widget.initialUrl}');
  }

  @override
  void deactivate() {
    print('[ADD LINK] deactivate');
    super.deactivate();
  }

  @override
  void dispose() {
    print('[ADD LINK] ======== dispose ========');
    print('[NAV STACK en dispose] ${StackTrace.current}');
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
    print('[ADD LINK] ======== dispose FIN ========');
  }

  Future<void> _processUrl(String url) async {
    print('[ADD LINK] _processUrl: detectando plataforma para $url');
    final platform = PlatformDetector.detect(url);
    print('[ADD LINK] plataforma detectada: ${platform.displayName}');
    setState(() {
      _detectedPlatform = platform;
      _isLoadingMetadata = true;
    });

    if (platform == PlatformType.unknown) {
      setState(() => _isLoadingMetadata = false);
      return;
    }

    final metadataService = ref.read(metadataServiceProvider);
    print('[METADATA] fetchMetadata iniciado para $url');
    try {
      final metadata = await metadataService.fetchMetadata(url, platform);
      print('[METADATA] título: ${metadata.title}');
      print('[METADATA] miniatura: ${metadata.thumbnail}');
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
          if (_titleController.text.isEmpty) {
            _titleController.text = metadata.title ?? '';
          }
          _thumbnailUrl = metadata.thumbnail;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMetadata = false);
    }

    _requestAiSuggestion();
  }

  Future<void> _requestAiSuggestion() async {
    final title = _titleController.text;
    if (title.isEmpty) return;

    final openaiService = ref.read(openaiServiceProvider);
    try {
      final result = await openaiService.suggestCategory(title);
      if (result.category != null && mounted) {
        setState(() {
          _showAiSuggestion = true;
          _aiCategory = result.category;
          _aiSuggestion = result.suggestion;
        });
      }
    } catch (_) {}
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
      await ref.read(categoryRepositoryProvider).ensureCategory(category);
      await ref.read(linkRepositoryProvider).saveLink(
            url: url,
            platform: platform,
            title: title,
            thumbnail: _thumbnailUrl,
            category: category,
          );

      ref.invalidate(allLinksProvider);
      ref.invalidate(allCategoriesProvider);

      if (mounted) {
        setState(() {
          _saved = true;
          _savedTitle = title;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleBack() {
    final hasUrl = _urlController.text.trim().isNotEmpty;
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasData = hasUrl || hasTitle ||
        _detectedPlatform != PlatformType.unknown ||
        (_selectedCategory != null &&
            _selectedCategory != AppConstants.defaultCategory) ||
        _thumbnailUrl != null;

    if (!hasData) {
      _goHome();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text(
            'Los cambios no guardados se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _urlController.clear();
              _titleController.clear();
              _goHome();
            },
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    print('[ADD LINK] _goHome() → context.go(AppConfig.homeRoute)');
    context.go(AppConfig.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    print('[ADD LINK] build');
    final colorScheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: _saved
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isSaving ? null : _handleBack,
                tooltip: 'Regresar',
              ),
        title: const Text('Agregar enlace'),
        actions: _saved
            ? null
            : [
                TextButton(
                  onPressed: _isSaving ? null : _saveLink,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
      ),
      body: _saved
          ? _buildSuccessView(colorScheme)
          : _buildForm(context, colorScheme, categoriesAsync),
      ),
    );
  }

  Widget _buildSuccessView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 44, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            Text('Video guardado',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_savedTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go(AppConfig.homeRoute),
              icon: const Icon(Icons.home_rounded, size: 20),
              label: const Text('Volver al inicio'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ColorScheme colorScheme,
      AsyncValue<List<CategoryModel>> categoriesAsync) {
    return Form(
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
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
                        showLabel: true),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Detectado',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: colorScheme
                                      .onPrimaryContainer)),
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
              decoration: const InputDecoration(labelText: 'Título'),
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
                        value: c.name, child: Text(c.name)))
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue:
                      items.any((i) => i.value == _selectedCategory)
                          ? _selectedCategory
                          : items.isNotEmpty
                              ? items.first.value
                              : null,
                  decoration:
                      const InputDecoration(labelText: 'Categoría'),
                  items: items,
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v),
                );
              },
            ),
            if (_showAiSuggestion && _aiCategory != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      colorScheme.tertiaryContainer.withAlpha(100),
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
                        Text('Sugerencia IA',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color: colorScheme.tertiary,
                                    fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Categoría sugerida: "$_aiCategory"',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    if (_aiSuggestion != null) ...[
                      const SizedBox(height: 4),
                      Text(_aiSuggestion!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
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
                          onPressed: () => setState(
                              () => _showAiSuggestion = false),
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(
                  _isSaving ? 'Guardando...' : 'Guardar video'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
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
          child: Icon(Icons.image_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withAlpha(100)),
        ),
      ),
    );
  }
}
