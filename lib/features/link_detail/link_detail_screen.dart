import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/link.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/widgets/platform_icon.dart';

class LinkDetailScreen extends ConsumerStatefulWidget {
  final String linkId;

  const LinkDetailScreen({super.key, required this.linkId});

  @override
  ConsumerState<LinkDetailScreen> createState() => _LinkDetailScreenState();
}

class _LinkDetailScreenState extends ConsumerState<LinkDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  String? _selectedCategory;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkAsync = ref.watch(linkByIdProvider(widget.linkId));
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          if (!_isEditing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (linkAsync.valueOrNull == null) return;
                final l = linkAsync.value!;
                switch (v) {
                  case 'share':
                    Share.share('${l.title}\n${l.url}');
                  case 'copy':
                    Clipboard.setData(ClipboardData(text: l.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Enlace copiado'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'share',
                    child: Row(children: [
                      Icon(Icons.share, size: 18),
                      SizedBox(width: 10),
                      Text('Compartir'),
                    ])),
                PopupMenuItem(
                    value: 'copy',
                    child: Row(children: [
                      Icon(Icons.copy, size: 18),
                      SizedBox(width: 10),
                      Text('Copiar enlace'),
                    ])),
              ],
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () => _toggleEdit(linkAsync.valueOrNull),
            tooltip: _isEditing ? 'Guardar' : 'Editar',
          ),
        ],
      ),
      body: linkAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (link) {
          if (link == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  const Text('Enlace no encontrado'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          if (!_isEditing && _titleController.text.isEmpty) {
            _titleController.text = link.title;
            _notesController.text = link.notes ?? '';
            _selectedCategory = link.category;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildThumbnailSection(context, link),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isEditing)
                        _buildEditableFields(context, link, categoriesAsync)
                      else
                        _buildDisplayFields(context, link),
                      const SizedBox(height: 20),
                      _buildActionButtons(context, link),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnailSection(BuildContext context, LinkModel link) {
    final platform = _getPlatform(link.platform);
    final platformColor = AppTheme.platformColor(platform);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (link.thumbnail != null)
              CachedNetworkImage(
                imageUrl: link.thumbnail!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    _buildThumbnailPlaceholder(context, platformColor),
                errorWidget: (_, __, ___) =>
                    _buildThumbnailPlaceholder(context, platformColor),
              )
            else
              _buildThumbnailPlaceholder(context, platformColor),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(200),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: PlatformIcon(
                  platform: platform,
                  size: 16,
                  showLabel: true,
                ),
              ),
            ),
            if (!_isEditing)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    ref.read(linkRepositoryProvider).toggleFavorite(link.id);
                    ref.invalidate(linkByIdProvider(widget.linkId));
                    ref.invalidate(allLinksProvider);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        link.favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 22,
                        color: link.favorite ? Colors.red : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(
      BuildContext context, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(180), color.withAlpha(80)],
        ),
      ),
      child: Center(
        child: Icon(Icons.play_circle_outline,
            size: 64, color: Colors.white.withAlpha(150)),
      ),
    );
  }

  Widget _buildDisplayFields(BuildContext context, LinkModel link) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          link.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.folder_outlined,
                size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              link.category,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              DateFormat('dd/MM/yyyy').format(link.createdAt),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        if (link.notes != null && link.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Notas',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            link.notes!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditableFields(BuildContext context, LinkModel link,
      AsyncValue<List<CategoryModel>> categoriesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          maxLength: AppConstants.maxTitleLength,
          decoration: const InputDecoration(
            labelText: 'Título',
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: AppConstants.maxNotesLength,
          decoration: const InputDecoration(
            labelText: 'Notas personales',
            hintText: 'Ingresa palabras clave, #hashtags, ideas o información '
                'que te ayude a localizar mejor tus links.',
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, LinkModel link) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () async {
            final url = link.url;
            if (url.isEmpty) {
              _showLinkError(context,
                  'No hay enlace para abrir.');
              return;
            }

            final fixedUrl = url.startsWith('http://') ||
                    url.startsWith('https://')
                ? url
                : 'https://$url';

            Uri uri;
            try {
              uri = Uri.parse(fixedUrl);
              if (!uri.hasScheme || uri.host.isEmpty) {
                _showLinkError(context, 'El enlace no es válido.');
                return;
              }
            } catch (_) {
              _showLinkError(context, 'El enlace no es válido.');
              return;
            }

            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              } else {
                _showLinkError(context,
                    'No se pudo abrir el enlace.');
              }
            } catch (_) {
              _showLinkError(context,
                  'Error al intentar abrir el enlace.');
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir video'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context, link),
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          label: Text(
            'Eliminar',
            style: TextStyle(color: colorScheme.error),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: colorScheme.error.withAlpha(100)),
          ),
        ),
      ],
    );
  }

  void _toggleEdit(LinkModel? link) {
    if (_isEditing && link != null) {
      final title = _titleController.text.trim();
      final notes = _notesController.text.trim();

      if (title.isNotEmpty) {
        ref.read(linkRepositoryProvider).updateLink(
              link.id,
              title: title,
              category: _selectedCategory,
              notes: notes.isEmpty ? null : notes,
            );
        ref.invalidate(linkByIdProvider(widget.linkId));
        ref.invalidate(allLinksProvider);
      }
    }

    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing && link != null) {
        _titleController.text = link.title;
        _notesController.text = link.notes ?? '';
        _selectedCategory = link.category;
      }
    });
  }

  void _confirmDelete(BuildContext context, LinkModel link) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar enlace'),
        content: const Text('¿Estás seguro de eliminar este video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(linkRepositoryProvider).deleteLink(link.id);
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  PlatformType _getPlatform(String name) {
    return PlatformType.values.firstWhere(
      (p) => p.name == name,
      orElse: () => PlatformType.unknown,
    );
  }

  void _showLinkError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
