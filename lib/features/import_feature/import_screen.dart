import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/url_extractor.dart';
import '../../core/services/platform_detector.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/category_providers.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _textController = TextEditingController();
  List<String> _extractedUrls = [];
  bool _isProcessing = false;
  String _statusMessage = '';

  void _extractUrls() {
    final text = _textController.text;
    final urls = UrlExtractor.extractSocialUrls(text);

    setState(() {
      _extractedUrls = urls;
      if (urls.isEmpty) {
        _statusMessage = 'No se encontraron enlaces de redes sociales.';
      } else {
        _statusMessage = '${urls.length} enlace(s) encontrado(s).';
      }
    });
  }

  Future<void> _importAll() async {
    if (_extractedUrls.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Procesando enlaces...';
    });

    final linkRepo = ref.read(linkRepositoryProvider);
    final metadataService = ref.read(metadataServiceProvider);

    int imported = 0;

    for (final url in _extractedUrls) {
      try {
        final platform = PlatformDetector.detect(url);
        final platformName = platform.name;

        final metadata = await metadataService.fetchMetadata(url, platform);

        await linkRepo.saveLink(
          url: url,
          platform: platformName,
          title: metadata.title ?? 'Video de ${platform.displayName}',
          thumbnail: metadata.thumbnail,
          category: AppConstants.defaultCategory,
        );

        imported++;
        setState(() {
          _statusMessage = 'Importados: $imported/${_extractedUrls.length}';
        });
      } catch (_) {}
    }

    setState(() {
      _isProcessing = false;
      _statusMessage = '¡$imported enlace(s) importado(s) exitosamente!';
      _extractedUrls = [];
      _textController.clear();
    });

    ref.invalidate(allLinksProvider);
    ref.invalidate(allCategoriesProvider);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar enlaces'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pega cualquier bloque de texto de WhatsApp. '
                      'La app extraerá automáticamente solo los enlaces '
                      'de TikTok, YouTube, Instagram y Facebook.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 8,
              onChanged: (_) => _extractUrls(),
              decoration: const InputDecoration(
                hintText: 'Pega aquí el texto con enlaces...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_extractedUrls.isNotEmpty) ...[
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_extractedUrls.length, (index) {
                final url = _extractedUrls[index];
                final platform = PlatformDetector.detect(url);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      _getPlatformIcon(platform),
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    subtitle: Text(
                      platform.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _importAll,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isProcessing
                      ? 'Importando...'
                      : 'Importar ${_extractedUrls.length} enlace(s)',
                ),
              ),
            ] else if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon(PlatformType platform) {
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
