import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/link.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/widgets/link_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, bool> _expandedCategories = {};
  final Set<String> _selectedLinkIds = {};
  bool _isSelectionMode = false;

  void _enterSelectionMode(String linkId) {
    setState(() {
      _isSelectionMode = true;
      _selectedLinkIds.add(linkId);
    });
  }

  void _toggleSelection(String linkId) {
    setState(() {
      if (_selectedLinkIds.contains(linkId)) {
        _selectedLinkIds.remove(linkId);
        if (_selectedLinkIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedLinkIds.add(linkId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedLinkIds.clear();
    });
  }

  void _showMoveToCategorySheet() {
    final categoriesAsync = ref.read(allCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Mover ${_selectedLinkIds.length} elemento(s) a:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ...categories.map((cat) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(cat.name),
                    onTap: () {
                      Navigator.pop(ctx);
                      _moveSelectedTo(cat.name);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveSelectedTo(String category) async {
    final repo = ref.read(linkRepositoryProvider);
    for (final id in _selectedLinkIds) {
      await repo.updateLink(id, category: category);
    }
    ref.invalidate(allLinksProvider);
    ref.invalidate(allCategoriesProvider);
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(allLinksProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedLinkIds.length} seleccionados'),
              actions: [
                TextButton.icon(
                  onPressed: _showMoveToCategorySheet,
                  icon: const Icon(Icons.drive_file_move_outlined),
                  label: const Text('Mover'),
                ),
              ],
            )
          : AppBar(
              title: const Text('Inventario Video'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => context.go(AppConfig.addLinkRoute),
                  tooltip: 'Agregar enlace',
                ),
              ],
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AppConfig.addLinkRoute),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo'),
            ),
      body: linksAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('Error al cargar los videos'),
            ],
          ),
        ),
        data: (links) {
          if (links.isEmpty) return _buildEmptyState(context);
          return _buildContent(context, links, categoriesAsync);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.video_library_rounded,
                  size: 44, color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin videos',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comparte desde cualquier red social\npara empezar a guardar videos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go(AppConfig.addLinkRoute),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Agregar primer video'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<LinkModel> links,
      AsyncValue<List<CategoryModel>> categoriesAsync) {
    final groupedLinks = <String, List<LinkModel>>{};

    for (final link in links) {
      groupedLinks.putIfAbsent(link.category, () => []).add(link);
    }

    final sortedCategories = groupedLinks.keys.toList()
      ..sort((a, b) {
        if (a == AppConstants.defaultCategory) return 1;
        if (b == AppConstants.defaultCategory) return -1;
        return a.compareTo(b);
      });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allLinksProvider);
      },
      edgeOffset: 80,
      child: CustomScrollView(
        slivers: [
          if (!_isSelectionMode)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: categoriesAsync.when(
                  loading: () => const SizedBox(height: 42),
                  error: (_, __) => const SizedBox(height: 42),
                  data: (categories) =>
                      _buildCategoryChips(context, categories, groupedLinks),
                ),
              ),
            ),
          for (final category in sortedCategories) ...[
            _buildCategoryHeader(context, category, groupedLinks[category]!),
            _buildCategoryGrid(context, category, groupedLinks[category]!),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context,
      List<CategoryModel> categories,
      Map<String, List<LinkModel>> groupedLinks) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isExpanded = _expandedCategories[cat.name] ?? true;
          final count = groupedLinks[cat.name]?.length ?? 0;

          return FilterChip(
            label: Text('${cat.name} ($count)'),
            selected: isExpanded,
            onSelected: (_) {
              setState(() {
                _expandedCategories[cat.name] = !isExpanded;
              });
            },
            selectedColor: colorScheme.primaryContainer,
            checkmarkColor: colorScheme.onPrimaryContainer,
            side: isExpanded
                ? BorderSide(color: colorScheme.primary, width: 1.5)
                : BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryHeader(
      BuildContext context, String category, List<LinkModel> links) {
    final isExpanded = _expandedCategories[category] ?? true;
    if (!isExpanded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      sliver: SliverToBoxAdapter(
        child: Text(
          category,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
      BuildContext context, String category, List<LinkModel> links) {
    final isExpanded = _expandedCategories[category] ?? true;
    if (!isExpanded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final link = links[index];
            return LinkCard(
              link: link,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedLinkIds.contains(link.id),
              onTap: _isSelectionMode
                  ? () => _toggleSelection(link.id)
                  : () => context
                      .push('${AppConfig.linkDetailRoute}/${link.id}'),
              onFavoriteToggle: _isSelectionMode
                  ? null
                  : () {
                      ref.read(linkRepositoryProvider).toggleFavorite(link.id);
                    },
              onLongPress: _isSelectionMode
                  ? null
                  : () => _enterSelectionMode(link.id),
            );
          },
          childCount: links.length,
        ),
      ),
    );
  }
}
