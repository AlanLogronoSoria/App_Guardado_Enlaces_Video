import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/link.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/category_icons.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  static const availableColors = [
    'FF4CAF50', 'FF9C27B0', 'FF2196F3', 'FFE91E63', 'FF3F51B5',
    'FFFF9800', 'FFF44336', 'FF009688', 'FF795548', 'FF607D8B',
    'FFCDDC39', 'FFFF5722',
  ];

  Widget _buildPreview(String? iconName, String? colorHex, String name) {
    final color = colorHex != null ? Color(int.parse(colorHex, radix: 16)) : null;
    final icon = iconDataFromName(iconName);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        if (name.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          final linksAsync = ref.watch(allLinksProvider);
          final linkCounts = <String, int>{};
          if (linksAsync.valueOrNull != null) {
            for (final l in linksAsync.value!) {
              linkCounts[l.category] = (linkCounts[l.category] ?? 0) + 1;
            }
          }

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off, size: 64,
                      color: colorScheme.onSurfaceVariant.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('No hay categorías',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: categories.length,
            itemBuilder: (context, index) => _buildItem(categories[index], linkCounts[categories[index].name] ?? 0),
          );
        },
      ),
    );
  }

  Widget _buildItem(CategoryModel category, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    final catColor = category.displayColor ?? colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: catColor.withAlpha(30),
          child: Icon(category.iconData, color: catColor, size: 20),
        ),
        title: Text(category.name,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${count == 1 ? '1 video' : '$count videos'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit': _showEditDialog(category); break;
              case 'merge': _showMergeDialog(category); break;
              case 'delete': _confirmDelete(category); break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Editar')])),
            const PopupMenuItem(value: 'merge', child: Row(children: [Icon(Icons.merge, size: 20), SizedBox(width: 12), Text('Fusionar')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 12), Text('Eliminar', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    String? icon = defaultCategoryIconName;
    String? color;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nueva categoría'),
          content: SizedBox(width: 320, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, autofocus: true, maxLength: 50, decoration: const InputDecoration(hintText: 'Nombre')),
              const SizedBox(height: 16),
              Row(children: [Text('Icono', style: Theme.of(context).textTheme.labelLarge), const Spacer(), _buildPreview(icon, color, nameCtrl.text)]),
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4, children: availableIconNames.map((name) {
                final ic = categoryIcons[name]!;
                return GestureDetector(
                onTap: () => setD(() => icon = name),
                child: Container(width: 40, height: 40, decoration: BoxDecoration(
                  color: icon == name ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ), child: Icon(ic, size: 22)),
              );}).toList()),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                GestureDetector(onTap: () => setD(() => color = null), child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color == null ? Theme.of(context).colorScheme.primary : Colors.grey, width: color == null ? 2.5 : 1)), child: const Icon(Icons.block, size: 20))),
                ...availableColors.map((c) => GestureDetector(onTap: () => setD(() => color = c), child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(int.parse(c, radix: 16)), border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2.5))))),
              ]),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) {
                ref.read(categoryRepositoryProvider).createCategory(n, icon: icon, color: color);
                Navigator.pop(ctx);
              }
            }, child: const Text('Crear')),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(CategoryModel category) {
    final nameCtrl = TextEditingController(text: category.name);
    String? icon = category.icon ?? defaultCategoryIconName;
    String? color = category.color;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Editar categoría'),
          content: SizedBox(width: 320, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, autofocus: true, maxLength: 50, decoration: const InputDecoration(hintText: 'Nombre')),
              const SizedBox(height: 16),
              Row(children: [Text('Icono', style: Theme.of(context).textTheme.labelLarge), const Spacer(), _buildPreview(icon, color, nameCtrl.text)]),
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4, children: availableIconNames.map((name) {
                final ic = categoryIcons[name]!;
                return GestureDetector(
                onTap: () => setD(() => icon = name),
                child: Container(width: 40, height: 40, decoration: BoxDecoration(
                  color: icon == name ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ), child: Icon(ic, size: 22)),
              );}).toList()),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                GestureDetector(onTap: () => setD(() => color = null), child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color == null ? Theme.of(context).colorScheme.primary : Colors.grey, width: color == null ? 2.5 : 1)), child: const Icon(Icons.block, size: 20))),
                ...availableColors.map((c) => GestureDetector(onTap: () => setD(() => color = c), child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(int.parse(c, radix: 16)), border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2.5))))),
              ]),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) {
                ref.read(categoryRepositoryProvider).updateCategory(category.id, name: n, icon: icon, color: color);
                Navigator.pop(ctx);
              }
            }, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }

  void _showMergeDialog(CategoryModel source) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final others = categoriesAsync.valueOrNull?.where((c) => c.id != source.id).toList() ?? [];
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay otras categorías para fusionar.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fusionar "${source.name}" con...'),
        content: SizedBox(width: double.maxFinite, child: ListView.builder(
          shrinkWrap: true, itemCount: others.length,
          itemBuilder: (_, i) => ListTile(leading: const Icon(Icons.folder), title: Text(others[i].name), onTap: () { Navigator.pop(ctx); _confirmMerge(source, others[i]); }),
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))],
      ),
    );
  }

  void _confirmMerge(CategoryModel source, CategoryModel target) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar fusión'),
        content: Text('Todos los enlaces de "${source.name}" se moverán a "${target.name}" y la categoría será eliminada. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            ref.read(categoryRepositoryProvider).mergeCategories(source.id, target.id);
            Navigator.pop(ctx);
          }, child: const Text('Fusionar')),
        ],
      ),
    );
  }

  void _confirmDelete(CategoryModel category) {
    if (category.name == AppConstants.defaultCategory) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede eliminar la categoría General.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('Los enlaces de "${category.name}" se moverán a "${AppConstants.defaultCategory}". ¿Eliminar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () {
            ref.read(categoryRepositoryProvider).deleteCategory(category.id);
            Navigator.pop(ctx);
          }, child: const Text('Eliminar')),
        ],
      ),
    );
  }
}
