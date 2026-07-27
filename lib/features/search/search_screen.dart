import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/widgets/link_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedPlatform = '';
  String _selectedCategory = '';
  bool _onlyFavorites = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider(query));

    final links = resultsAsync.valueOrNull ?? [];
    final categories = links.map((l) => l.category).toSet().toList()..sort();
    final platforms = links.map((l) => l.platform).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por título, categoría o plataforma...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (platforms.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Favoritos',
                      selected: _onlyFavorites,
                      onSelected: (v) =>
                          setState(() => _onlyFavorites = v),
                      icon: Icons.favorite,
                    ),
                    const SizedBox(width: 8),
                    ...platforms.map((p) {
                      final displayName = PlatformType.values
                          .firstWhere((pt) => pt.name == p,
                              orElse: () => PlatformType.unknown)
                          .displayName;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: displayName,
                          selected: _selectedPlatform == p,
                          onSelected: (v) => setState(
                              () => _selectedPlatform = v ? p : ''),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          if (categories.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: c,
                        selected: _selectedCategory == c,
                        onSelected: (v) => setState(
                            () => _selectedCategory = v ? c : ''),
                        icon: Icons.folder,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: resultsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (results) {
                var filtered = results;

                if (_selectedPlatform.isNotEmpty) {
                  filtered = filtered
                      .where((l) => l.platform == _selectedPlatform)
                      .toList();
                }
                if (_selectedCategory.isNotEmpty) {
                  filtered = filtered
                      .where((l) => l.category == _selectedCategory)
                      .toList();
                }
                if (_onlyFavorites) {
                  filtered =
                      filtered.where((l) => l.favorite).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withAlpha(100)),
                        const SizedBox(height: 16),
                        Text(
                          'Sin resultados',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final link = filtered[index];
                    return LinkCard(
                      link: link,
                      onTap: () => context.push(
                          '${AppConfig.linkDetailRoute}/${link.id}'),
                      onFavoriteToggle: () {
                        ref
                            .read(linkRepositoryProvider)
                            .toggleFavorite(link.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    IconData? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: 16) : null,
      selected: selected,
      onSelected: onSelected,
      selectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
