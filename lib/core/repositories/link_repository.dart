import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../shared/models/link.dart';

class LinkRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  LinkRepository(this._db);

  Future<List<LinkModel>> getAllLinks() async {
    final rows = await _db.getAllLinks();
    return _toModels(rows);
  }

  Future<List<LinkModel>> getLinksByCategory(String category) async {
    final rows = await _db.getLinksByCategory(category);
    return _toModels(rows);
  }

  Future<LinkModel?> getLinkById(String id) async {
    final row = await _db.getLinkById(id);
    if (row == null) return null;
    return _toModel(row);
  }

  Future<LinkModel> saveLink({
    required String url,
    required String platform,
    required String title,
    String? thumbnail,
    required String category,
    String? notes,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    final entry = LinkTableCompanion(
      id: Value(id),
      url: Value(url),
      platform: Value(platform),
      title: Value(title),
      thumbnail: Value.absentIfNull(thumbnail),
      category: Value(category),
      favorite: const Value(false),
      notes: Value.absentIfNull(notes),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.insertLink(entry);
    _db.incrementModifications();
    final row = await _db.getLinkById(id);
    return _toModel(row!);
  }

  Future<void> deleteLink(String id) async {
    await _db.deleteLink(id);
    _db.incrementModifications();
  }

  Future<void> updateLink(String id, {
    String? title,
    String? category,
    String? notes,
    String? thumbnail,
    bool? favorite,
  }) async {
    await _db.updateLinkFields(
      id,
      title: title,
      category: category,
      notes: notes,
      thumbnail: thumbnail,
      favorite: favorite,
    );
    _db.incrementModifications();
  }

  Future<List<LinkModel>> searchLinks(String query) async {
    final rows = await _db.searchLinks(query);
    return _toModels(rows);
  }

  Future<List<LinkModel>> getFilteredLinks({
    String? platform,
    String? category,
    bool? favorite,
    DateTime? after,
    DateTime? before,
  }) async {
    final rows = await _db.getFilteredLinks(
      platform: platform,
      category: category,
      favorite: favorite,
      after: after,
      before: before,
    );
    return _toModels(rows);
  }

  Future<void> toggleFavorite(String id) async {
    await _db.toggleFavorite(id);
    _db.incrementModifications();
  }

  Future<void> batchSaveLinks(List<Map<String, String>> links) async {
    final now = DateTime.now();
    final entries = links.map((l) {
      return LinkTableCompanion(
        id: Value(_uuid.v4()),
        url: Value(l['url']!),
        platform: Value(l['platform']!),
        title: Value(l['title']!),
        thumbnail: Value.absentIfNull(l['thumbnail']),
        category: Value(l['category'] ?? 'General'),
        favorite: const Value(false),
        notes: Value.absentIfNull(l['notes']),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
    }).toList();

    await _db.batchInsertLinks(entries);
    _db.incrementModifications();
  }

  Stream<List<LinkModel>> watchAllLinks() {
    return _db.watchAllLinks().map(_toModels);
  }

  Stream<List<LinkModel>> watchLinksByCategory(String category) {
    return _db.watchLinksByCategory(category).map(_toModels);
  }

  LinkModel _toModel(LinkTableData row) => LinkModel(
        id: row.id,
        url: row.url,
        platform: row.platform,
        title: row.title,
        thumbnail: row.thumbnail,
        category: row.category,
        favorite: row.favorite,
        notes: row.notes,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  List<LinkModel> _toModels(List<LinkTableData> rows) =>
      rows.map(_toModel).toList();
}
