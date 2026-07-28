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
    return rows.map(_toModel).toList();
  }

  Future<CategoryModel?> getCategoryByName(String name) async {
    final row = await _db.getCategoryByName(name);
    if (row == null) return null;
    return _toModel(row);
  }

  Future<CategoryModel> createCategory(String name,
      {int? icon, String? color}) async {
    final existing = await _db.getCategoryByName(name);
    if (existing != null) {
      return _toModel(existing);
    }

    final now = DateTime.now();
    final id = _uuid.v4();

    final entry = CategoryTableCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value.absentIfNull(icon),
      color: Value.absentIfNull(color),
      createdAt: Value(now),
    );

    await _db.insertCategory(entry);
    _db.incrementModifications();
    return CategoryModel(
        id: id, name: name, icon: icon, color: color, createdAt: now);
  }

  Future<void> deleteCategory(String id) async {
    final category = await _db.getCategoryById(id);
    if (category == null) return;

    await _db.renameCategoryForLinks(
        category.name, AppConstants.defaultCategory);
    await _db.deleteCategory(id);
    _db.incrementModifications();
  }

  Future<void> updateCategory(String id,
      {String? name, int? icon, String? color}) async {
    final cat = await _db.getCategoryById(id);
    if (cat == null) return;

    if (name != null && name != cat.name) {
      await _db.renameCategoryForLinks(cat.name, name);
    }

    await (_db.update(_db.categoryTable)..where((t) => t.id.equals(id))).write(
      CategoryTableCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        icon: Value.absentIfNull(icon),
        color: Value.absentIfNull(color),
      ),
    );
    _db.incrementModifications();
  }

  Future<void> mergeCategories(String sourceId, String targetId) async {
    final source = await _db.getCategoryById(sourceId);
    final target = await _db.getCategoryById(targetId);
    if (source == null || target == null) return;

    await _db.renameCategoryForLinks(source.name, target.name);
    await _db.deleteCategory(sourceId);
    _db.incrementModifications();
  }

  Future<CategoryModel> ensureCategory(String name) async {
    final existing = await _db.getCategoryByName(name);
    if (existing != null) return _toModel(existing);
    return createCategory(name);
  }

  Stream<List<CategoryModel>> watchAllCategories() {
    return _db.watchAllCategories().map((rows) => rows.map(_toModel).toList());
  }

  CategoryModel _toModel(CategoryTableData row) => CategoryModel(
        id: row.id,
        name: row.name,
        icon: row.icon,
        color: row.color,
        createdAt: row.createdAt,
      );
}
