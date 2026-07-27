import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/link.dart';
import '../../shared/providers/history_providers.dart';
import '../../core/theme/app_theme.dart';

class ShareHistoryScreen extends ConsumerStatefulWidget {
  const ShareHistoryScreen({super.key});

  @override
  ConsumerState<ShareHistoryScreen> createState() =>
      _ShareHistoryScreenState();
}

class _ShareHistoryScreenState extends ConsumerState<ShareHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterPlatform = '';
  String _filterCategory = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(shareHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar en historial...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'Todos',
                    selected: _filterPlatform.isEmpty &&
                        _filterCategory.isEmpty,
                    onSelected: (_) => setState(() {
                      _filterPlatform = '';
                      _filterCategory = '';
                    }),
                  ),
                  const SizedBox(width: 6),
                  for (final platform in PlatformType.values.where(
                      (p) => p != PlatformType.unknown))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildFilterChip(
                        label: platform.displayName,
                        selected: _filterPlatform == platform.name,
                        onSelected: (_) => setState(() {
                          _filterPlatform =
                              _filterPlatform == platform.name
                                  ? ''
                                  : platform.name;
                          _filterCategory = '';
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (links) {
                var filtered = links.where((l) {
                  if (_searchQuery.isNotEmpty) {
                    final title = l.title.toLowerCase();
                    final cat = l.category.toLowerCase();
                    final plat = PlatformType.values
                        .firstWhere((p) => p.name == l.platform,
                            orElse: () => PlatformType.unknown)
                        .displayName
                        .toLowerCase();
                    if (!title.contains(_searchQuery) &&
                        !cat.contains(_searchQuery) &&
                        !plat.contains(_searchQuery)) {
                      return false;
                    }
                  }
                  if (_filterPlatform.isNotEmpty &&
                      l.platform != _filterPlatform) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 48,
                            color: colorScheme.onSurfaceVariant
                                .withAlpha(100)),
                        const SizedBox(height: 16),
                        Text('Sin historial',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: colorScheme
                                        .onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final link = filtered[index];
                    return _buildHistoryItem(context, link, colorScheme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, LinkModel link, ColorScheme colorScheme) {
    final platform = PlatformType.values.firstWhere(
      (p) => p.name == link.platform,
      orElse: () => PlatformType.unknown,
    );
    final platformColor = AppTheme.platformColor(platform);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
            '${AppConfig.linkDetailRoute}/${link.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 48,
                  decoration: BoxDecoration(
                    color: platformColor.withAlpha(30),
                  ),
                  child: Icon(Icons.play_circle_outline,
                      size: 24,
                      color: platformColor.withAlpha(150)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(link.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: platformColor.withAlpha(25),
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: Text(platform.displayName,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: platformColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.folder_outlined,
                            size: 12,
                            color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(link.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Guardado',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yy HH:mm')
                        .format(link.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onSelected,
      selectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
