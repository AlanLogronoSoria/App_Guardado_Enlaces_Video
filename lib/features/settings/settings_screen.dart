import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../main.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: 'Apariencia',
            children: [
              ListTile(
                leading: Icon(Icons.dark_mode_outlined,
                    color: colorScheme.primary),
                title: const Text('Modo oscuro'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                        icon: Icon(Icons.brightness_auto, size: 18)),
                    ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Claro'),
                        icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Oscuro'),
                        icon: Icon(Icons.dark_mode, size: 18)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (value) {
                    ref.read(themeModeProvider.notifier).state =
                        value.first;
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'Aplicación',
            children: [
              ListTile(
                leading:
                    Icon(Icons.info_outline, color: colorScheme.primary),
                title: const Text('Acerca de'),
                subtitle: const Text('Versión 1.0.0'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'Datos',
            children: [
              ListTile(
                leading: Icon(Icons.backup_outlined,
                    color: colorScheme.primary),
                title: const Text('Copias de seguridad'),
                subtitle: const Text('Gestionar respaldos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppConfig.backupsRoute),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'Soporte',
            children: [
              ListTile(
                leading:
                    Icon(Icons.help_outline, color: colorScheme.primary),
                title: const Text('Ayuda'),
                subtitle: const Text('Cómo usar la aplicación'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHelp(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Inventario Video v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cómo usar la app'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpItem(
                icon: Icons.share,
                title: 'Compartir desde otra app',
                description:
                    'Cuando veas un video en TikTok, YouTube, Instagram o Facebook, '
                    'presiona Compartir y selecciona Inventario Video.',
              ),
              _HelpItem(
                icon: Icons.add,
                title: 'Agregar manualmente',
                description:
                    'Presiona el botón + para agregar un enlace manualmente. '
                    'La app detectará la plataforma automáticamente.',
              ),
              _HelpItem(
                icon: Icons.file_download,
                title: 'Importar desde WhatsApp',
                description:
                    'Copia el texto de un chat, pégalo en Importar y la app extraerá '
                    'automáticamente los enlaces de videos.',
              ),
              _HelpItem(
                icon: Icons.search,
                title: 'Buscar',
                description:
                    'Usa la barra de búsqueda para encontrar videos por título, '
                    'categoría o plataforma.',
              ),
              _HelpItem(
                icon: Icons.category,
                title: 'Categorías',
                description:
                    'Organiza tus videos en categorías. Puedes crear, editar, '
                    'fusionar y eliminar categorías.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
