import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/link.dart';
import 'core_providers.dart';

final allLinksProvider = StreamProvider<List<LinkModel>>((ref) {
  final repo = ref.watch(linkRepositoryProvider);
  return repo.watchAllLinks();
});

final linksByCategoryProvider =
    StreamProvider.family<List<LinkModel>, String>((ref, category) {
  final repo = ref.watch(linkRepositoryProvider);
  return repo.watchLinksByCategory(category);
});

final linkByIdProvider =
    FutureProvider.family<LinkModel?, String>((ref, id) {
  final repo = ref.watch(linkRepositoryProvider);
  return repo.getLinkById(id);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.family<List<LinkModel>, String>((ref, query) {
  final repo = ref.watch(linkRepositoryProvider);
  if (query.isEmpty) return repo.getAllLinks();
  return repo.searchLinks(query);
});
