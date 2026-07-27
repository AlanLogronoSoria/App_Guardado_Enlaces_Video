import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../shared/models/link.dart';
import '../constants/app_constants.dart';

class CategoryRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CategoryRepository(this._db);

  Future<List<CategoryModel>> getAllCategories() async {
    final rows = await _db.getAllCategories();
    return rows
        .map((r) => CategoryModel(
              id: r.id,
              name: r.name,
              createdAt: r.createdAt,
            ))
        .toList();
  }

  Future<CategoryModel?> getCategoryByName(String name) async {
    final row = await _db.getCategoryByName(name);
    if (row == null) return null;
    return CategoryModel(id: row.id, name: row.name, createdAt: row.createdAt);
  }

  Future<CategoryModel> createCategory(String name) async {
    final existing = await _db.getCategoryByName(name);
    if (existing != null) {
      return CategoryModel(
          id: existing.id, name: existing.name, createdAt: existing.createdAt);
    }

    final now = DateTime.now();
    final id = _uuid.v4();

    final entry = CategoryTableCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(now),
    );

    await _db.insertCategory(entry);
    _db.incrementModifications();
    return CategoryModel(id: id, name: name, createdAt: now);
  }

  Future<void> deleteCategory(String id) async {
    final category = await _db.getCategoryById(id);
    if (category == null) return;

    await _db.renameCategoryForLinks(category.name, AppConstants.defaultCategory);
    await _db.deleteCategory(id);
    _db.incrementModifications();
  }

  Future<void> updateCategory(String id, String newName) async {
    final category = await _db.getCategoryById(id);
    if (category == null) return;

    await _db.renameCategoryForLinks(category.name, newName);
    await _db.updateCategoryName(id, newName);
    _db.incrementModifications();
  }

  Future<void> mergeCategories(
      String sourceId, String targetId) async {
    final source = await _db.getCategoryById(sourceId);
    final target = await _db.getCategoryById(targetId);
    if (source == null || target == null) return;

    await _db.renameCategoryForLinks(source.name, target.name);
    await _db.deleteCategory(sourceId);
    _db.incrementModifications();
  }

  Future<CategoryModel> ensureCategory(String name) async {
    final existing = await _db.getCategoryByName(name);
    if (existing != null) {
      return CategoryModel(
          id: existing.id, name: existing.name, createdAt: existing.createdAt);
    }
    return createCategory(name);
  }

  Stream<List<CategoryModel>> watchAllCategories() {
    return _db.watchAllCategories().map((rows) => rows
        .map((r) => CategoryModel(
              id: r.id,
              name: r.name,
              createdAt: r.createdAt,
            ))
        .toList());
  }
}
