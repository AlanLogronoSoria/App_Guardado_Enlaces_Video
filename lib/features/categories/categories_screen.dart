import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/link.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../core/constants/app_constants.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text(
                    'No hay categorías',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryItem(context, category);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, CategoryModel category) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.folder_rounded,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          category.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditCategoryDialog(context, category);
                break;
              case 'merge':
                _showMergeCategoryDialog(context, category);
                break;
              case 'delete':
                _confirmDeleteCategory(context, category);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 12),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'merge',
              child: Row(
                children: [
                  Icon(Icons.merge, size: 20),
                  SizedBox(width: 12),
                  Text('Fusionar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCategoryDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: AppConstants.maxCategoryNameLength,
          decoration: const InputDecoration(
            hintText: 'Nombre de la categoría',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref
                  .read(categoryRepositoryProvider)
                  .createCategory(value.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(categoryRepositoryProvider)
                    .createCategory(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(
      BuildContext context, CategoryModel category) {
    final controller = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: AppConstants.maxCategoryNameLength,
          decoration: const InputDecoration(
            hintText: 'Nuevo nombre',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && value.trim() != category.name) {
              ref
                  .read(categoryRepositoryProvider)
                  .updateCategory(category.id, value.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != category.name) {
                ref
                    .read(categoryRepositoryProvider)
                    .updateCategory(category.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showMergeCategoryDialog(
      BuildContext context, CategoryModel source) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final otherCategories = categoriesAsync.valueOrNull
            ?.where((c) => c.id != source.id)
            .toList() ??
        [];

    if (otherCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay otras categorías para fusionar.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fusionar "${source.name}" con...'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherCategories.length,
            itemBuilder: (context, index) {
              final target = otherCategories[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(target.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmMerge(context, source, target);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _confirmMerge(BuildContext context, CategoryModel source,
      CategoryModel target) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar fusión'),
        content: Text(
          'Todos los enlaces de "${source.name}" se moverán a '
          '"${target.name}" y la categoría "${source.name}" será eliminada. '
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(categoryRepositoryProvider)
                  .mergeCategories(source.id, target.id);
              Navigator.pop(ctx);
            },
            child: const Text('Fusionar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
      BuildContext context, CategoryModel category) {
    if (category.name == AppConstants.defaultCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se puede eliminar la categoría General.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          'Los enlaces de "${category.name}" se moverán a '
          '"${AppConstants.defaultCategory}". ¿Eliminar?',
        ),
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
              ref
                  .read(categoryRepositoryProvider)
                  .deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
