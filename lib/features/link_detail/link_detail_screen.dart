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
            padding: const EdgeInsets.only(bottom: 40),
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
                      else ...[
                        _buildMetaChips(context, link),
                        const SizedBox(height: 16),
                        _buildTitle(context, link),
                        if (link.notes != null && link.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildNotesCard(context, link),
                        ],
                        const SizedBox(height: 20),
                        _buildOpenButton(context, link),
                        const SizedBox(height: 20),
                        _buildQuickActions(context, link),
                        const SizedBox(height: 20),
                        _buildInfoCards(context, link),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context, link),
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          label: Text('Eliminar', style: TextStyle(color: colorScheme.error)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            side: BorderSide(color: colorScheme.error.withAlpha(100)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        _buildActionButtons(context, link),
                      ],
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

  Widget _buildMetaChips(BuildContext context, LinkModel link) {
    final platform = _getPlatform(link.platform);
    final relativeDate = _relativeDate(link.createdAt);

    return Wrap(spacing: 8, runSpacing: 8, children: [
      _chip(context, _platformIconData(platform), platform.displayName),
      _chip(context, Icons.folder_rounded, link.category),
      _chip(context, Icons.schedule, relativeDate),
    ]);
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildTitle(BuildContext context, LinkModel link) {
    return Text(link.title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.25));
  }

  Widget _buildOpenButton(BuildContext context, LinkModel link) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: () async {
          final url = link.url;
          if (url.isEmpty) { _showLinkError(context, 'No hay enlace para abrir.'); return; }
          final fixedUrl = url.startsWith('http://') || url.startsWith('https://') ? url : 'https://$url';
          Uri uri;
          try { uri = Uri.parse(fixedUrl); if (!uri.hasScheme || uri.host.isEmpty) { _showLinkError(context, 'El enlace no es válido.'); return; } } catch (_) { _showLinkError(context, 'El enlace no es válido.'); return; }
          try {
            if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
            else { _showLinkError(context, 'No se pudo abrir el enlace.'); }
          } catch (_) { _showLinkError(context, 'Error al intentar abrir el enlace.'); }
        },
        icon: const Icon(Icons.play_circle_filled, size: 22),
        label: const Text('Abrir video'),
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, LinkModel link) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(child: _actionCard(context, link.favorite ? Icons.favorite : Icons.favorite_border, 'Favorito', link.favorite ? Colors.red : colorScheme.primary, () {
        ref.read(linkRepositoryProvider).toggleFavorite(link.id);
        ref.invalidate(linkByIdProvider(widget.linkId));
        ref.invalidate(allLinksProvider);
      })),
      const SizedBox(width: 12),
      Expanded(child: _actionCard(context, Icons.share, 'Compartir', colorScheme.primary, () => Share.share('${link.title}\n${link.url}'))),
      const SizedBox(width: 12),
      Expanded(child: _actionCard(context, Icons.copy, 'Copiar', colorScheme.primary, () {
        Clipboard.setData(ClipboardData(text: link.url));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Enlace copiado'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 2)));
      })),
    ]);
  }

  Widget _actionCard(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 88,
      child: Material(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 8),
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, LinkModel link) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.edit_note, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Notas personales', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(link.notes!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
        ]),
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context, LinkModel link) {
    final host = Uri.tryParse(link.url)?.host ?? link.url;
    final displayUrl = host.length > 30 ? '${host.substring(0, 30)}...' : host;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _infoRow(context, Icons.calendar_today, 'Fecha', DateFormat('dd MMM yyyy').format(link.createdAt)),
          const Divider(height: 20),
          _infoRow(context, Icons.folder_rounded, 'Categoría', link.category),
          const Divider(height: 20),
          _infoRow(context, Icons.link, 'Origen', displayUrl),
        ]),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 10),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const Spacer(),
      Flexible(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]);
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} semanas';
    return DateFormat('dd MMM yyyy').format(date);
  }

  IconData _platformIconData(PlatformType platform) {
    switch (platform) {
      case PlatformType.tiktok: return Icons.music_note;
      case PlatformType.youtube: return Icons.play_circle_filled;
      case PlatformType.instagram: return Icons.camera_alt;
      case PlatformType.facebook: return Icons.people;
      case PlatformType.unknown: return Icons.link;
    }
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
