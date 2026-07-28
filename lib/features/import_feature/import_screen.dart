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
  bool _isComplete = false;
  int _importedCount = 0;

  void _extractUrls() {
    final text = _textController.text;
    final urls = UrlExtractor.extractSocialUrls(text);
    setState(() {
      _extractedUrls = urls;
      _isComplete = false;
      _statusMessage = urls.isEmpty
          ? 'No se encontraron enlaces de redes sociales.'
          : '${urls.length} enlace(s) encontrado(s).';
    });
  }

  Future<void> _importAll() async {
    if (_extractedUrls.isEmpty) return;
    setState(() { _isProcessing = true; _statusMessage = 'Procesando enlaces...'; });

    final linkRepo = ref.read(linkRepositoryProvider);
    final metadataService = ref.read(metadataServiceProvider);
    int imported = 0;

    for (final url in _extractedUrls) {
      try {
        final platform = PlatformDetector.detect(url);
        final metadata = await metadataService.fetchMetadata(url, platform);
        await linkRepo.saveLink(
          url: url, platform: platform.name,
          title: metadata.title ?? 'Video de ${platform.displayName}',
          thumbnail: metadata.thumbnail, category: AppConstants.defaultCategory,
        );
        imported++;
        setState(() { _statusMessage = 'Importados: $imported/${_extractedUrls.length}'; });
      } catch (_) {}
    }

    setState(() {
      _isProcessing = false;
      _isComplete = true;
      _importedCount = imported;
      _statusMessage = '¡$imported enlace(s) importado(s) exitosamente!';
      _extractedUrls = [];
      _textController.clear();
    });
    ref.invalidate(allLinksProvider);
    ref.invalidate(allCategoriesProvider);
  }

  @override
  void dispose() { _textController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _textController.text.isNotEmpty;
    final hasUrls = _extractedUrls.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar enlaces')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              Text('Pega grupos de enlaces para registrarlos automáticamente.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('El sistema detectará la plataforma, obtendrá el título\ny organizará los videos por categorías.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant.withAlpha(hasUrls ? 200 : 80), width: 1.5),
              color: colorScheme.surfaceContainerHighest.withAlpha(40),
            ),
            child: Column(children: [
              if (!hasText && !_isComplete) ...[
                const SizedBox(height: 28),
                Icon(Icons.link_rounded, size: 36, color: colorScheme.primary.withAlpha(120)),
                const SizedBox(height: 12),
                Text('Pega tus enlaces aquí',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Copia y pega varios enlaces desde\nWhatsApp, Notas o cualquier aplicación.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withAlpha(160))),
                const SizedBox(height: 20),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(12, hasText ? 8 : 0, 12, 8),
                child: TextField(
                  controller: _textController,
                  maxLines: hasText ? 8 : 4,
                  onChanged: (_) => _extractUrls(),
                  decoration: InputDecoration(
                    hintText: 'Pega aquí uno o varios enlaces...\n\nhttps://youtube.com/...\nhttps://tiktok.com/...\nhttps://vimeo.com/...',
                    hintMaxLines: 5,
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              if (hasUrls)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text('${_extractedUrls.length} enlaces detectados',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Formato soportado', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                Text('• Enlaces separados por líneas\n• Enlaces separados por comas\n• Grupos completos copiados desde WhatsApp\n• Enlaces mezclados con texto',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.6)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('https://youtube.com/...\nhttps://youtube.com/...\nhttps://vimeo.com/...\nhttps://tiktok.com/...',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colorScheme.onSurfaceVariant)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isComplete
                ? Card(
                    key: const ValueKey('done'),
                    color: Colors.green.withAlpha(15),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Icon(Icons.check_circle_rounded, size: 40, color: Colors.green.shade600),
                        const SizedBox(height: 8),
                        Text('Importación completada', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('$_importedCount enlaces registrados',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
                      ]),
                    ),
                  )
                : _isProcessing
                    ? Card(
                        key: const ValueKey('loading'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(height: 12),
                            Text(_statusMessage, style: Theme.of(context).textTheme.bodyMedium),
                          ]),
                        ),
                      )
                    : hasUrls
                        ? FilledButton.icon(
                            key: const ValueKey('import'),
                            onPressed: _importAll,
                            icon: const Icon(Icons.download_rounded),
                            label: Text('Importar (${_extractedUrls.length} enlaces)'),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                          )
                        : const SizedBox.shrink(),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
