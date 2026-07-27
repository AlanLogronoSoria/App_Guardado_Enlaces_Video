import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/link.dart';
import 'core_providers.dart';

final allCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAllCategories();
});
