import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';
import '../shared/models/backup_result.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LinkTable, CategoryTable, BackupStatusTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTest(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_link_category ON link_table (category)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_link_platform ON link_table (platform)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_link_created_at ON link_table (created_at)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_link_favorite ON link_table (favorite)');
          }
          if (from < 4) {
            await customStatement(
                'ALTER TABLE link_table ADD COLUMN source TEXT');
          }
        },
      );

  Future<List<LinkTableData>> getAllLinks() =>
      (select(linkTable)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<List<LinkTableData>> getShareLinks() =>
      (select(linkTable)
            ..where((t) => t.source.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<List<LinkTableData>> getLinksByCategory(String category) =>
      (select(linkTable)
            ..where((t) => t.category.equals(category))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<LinkTableData?> getLinkById(String id) =>
      (select(linkTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertLink(LinkTableCompanion entry) =>
      into(linkTable).insertOnConflictUpdate(entry);

  Future<void> deleteLink(String id) =>
      (delete(linkTable)..where((t) => t.id.equals(id))).go();

  Future<void> updateLinkFields(String id,
      {String? title,
      String? category,
      String? notes,
      String? thumbnail,
      bool? favorite}) {
    return (update(linkTable)..where((t) => t.id.equals(id))).write(
      LinkTableCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        thumbnail: thumbnail != null ? Value(thumbnail) : const Value.absent(),
        favorite: favorite != null ? Value(favorite) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<LinkTableData>> searchLinks(String query) {
    final q = '%$query%';
    return (select(linkTable)
          ..where((t) =>
              t.title.like(q) |
              t.category.like(q) |
              t.platform.like(q) |
              t.notes.like(q))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<LinkTableData>> getFilteredLinks({
    String? platform,
    String? category,
    bool? favorite,
    DateTime? after,
    DateTime? before,
  }) {
    var query = select(linkTable);

    final List<Expression<bool>> conditions = [];

    if (platform != null && platform.isNotEmpty) {
      conditions.add(linkTable.platform.equals(platform));
    }
    if (category != null && category.isNotEmpty) {
      conditions.add(linkTable.category.equals(category));
    }
    if (favorite != null && favorite) {
      conditions.add(linkTable.favorite.equals(true));
    }
    if (after != null) {
      conditions.add(linkTable.createdAt.isBiggerThanValue(after));
    }
    if (before != null) {
      conditions.add(linkTable.createdAt.isSmallerThanValue(before));
    }

    if (conditions.isNotEmpty) {
      var first = conditions.first;
      for (var i = 1; i < conditions.length; i++) {
        first = first & conditions[i];
      }
      query = (query..where((t) => first));
    }

    query = (query..orderBy([(t) => OrderingTerm.desc(t.createdAt)]));

    return query.get();
  }

  Future<void> toggleFavorite(String id) async {
    final link = await getLinkById(id);
    if (link != null) {
      await updateLinkFields(id, favorite: !link.favorite);
    }
  }

  Future<void> batchInsertLinks(List<LinkTableCompanion> entries) =>
      batch((batch) {
        for (final entry in entries) {
          batch.insert(linkTable, entry, mode: InsertMode.insertOrReplace);
        }
      });

  Future<int> deleteAllLinks() => delete(linkTable).go();

  Future<int> deleteAllCategories() => delete(categoryTable).go();

  Future<void> batchInsertCategoryModels(
      List<CategoryTableCompanion> entries) =>
      batch((batch) {
        for (final entry in entries) {
          batch.insert(categoryTable, entry, mode: InsertMode.insertOrReplace);
        }
      });

  Future<void> batchInsertLinkModels(
      List<LinkTableCompanion> entries) =>
      batch((batch) {
        for (final entry in entries) {
          batch.insert(linkTable, entry, mode: InsertMode.insertOrReplace);
        }
      });

  Future<List<CategoryTableData>> getAllCategories() =>
      (select(categoryTable)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<CategoryTableData?> getCategoryById(String id) =>
      (select(categoryTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<CategoryTableData?> getCategoryByName(String name) =>
      (select(categoryTable)..where((t) => t.name.equals(name)))
          .getSingleOrNull();

  Future<void> insertCategory(CategoryTableCompanion entry) =>
      into(categoryTable).insertOnConflictUpdate(entry);

  Future<void> deleteCategory(String id) =>
      (delete(categoryTable)..where((t) => t.id.equals(id))).go();

  Future<void> updateCategoryName(String id, String newName) =>
      (update(categoryTable)..where((t) => t.id.equals(id)))
          .write(CategoryTableCompanion(name: Value(newName)));

  Future<void> renameCategoryForLinks(
      String oldName, String newName) async {
    await (update(linkTable)..where((t) => t.category.equals(oldName)))
        .write(LinkTableCompanion(
      category: Value(newName),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<int> getLinkCount() => linkTable.count().getSingle();

  Future<int> getCategoryCount() => categoryTable.count().getSingle();

  Stream<List<LinkTableData>> watchAllLinks() =>
      (select(linkTable)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Stream<List<LinkTableData>> watchLinksByCategory(String category) =>
      (select(linkTable)
            ..where((t) => t.category.equals(category))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Stream<List<CategoryTableData>> watchAllCategories() =>
      (select(categoryTable)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<BackupStatusTableData?> getBackupStatus() =>
      (select(backupStatusTable)..limit(1)).getSingleOrNull();

  Future<void> ensureBackupStatus() async {
    final existing = await getBackupStatus();
    if (existing == null) {
      await into(backupStatusTable).insert(
        BackupStatusTableCompanion(
          modificationsSinceLastBackup: const Value(0),
          attemptCount: const Value(0),
          isRunning: const Value(false),
        ),
      );
    }
  }

  Future<void> incrementModifications() async {
    final status = await getBackupStatus();
    if (status == null) return;
    await (update(backupStatusTable)
          ..where((t) => t.id.equals(status.id)))
        .write(BackupStatusTableCompanion.custom(
      modificationsSinceLastBackup:
          backupStatusTable.modificationsSinceLastBackup +
              const Constant(1),
    ));
  }

  Future<BackupResult> onBackupSuccess(String message, String fileName) async {
    final status = await getBackupStatus();
    if (status == null) return const BackupFailure(error: 'Estado no encontrado');
    await (update(backupStatusTable)
          ..where((t) => t.id.equals(status.id)))
        .write(BackupStatusTableCompanion(
      lastBackupAt: Value(DateTime.now()),
      modificationsSinceLastBackup: const Value(0),
      lastResult: Value(message),
      lastAttemptAt: Value(DateTime.now()),
      attemptCount: const Value(0),
      isRunning: const Value(false),
    ));
    return BackupSuccess(message: message, fileName: fileName);
  }

  Future<BackupResult> onBackupFailure(String error) async {
    final status = await getBackupStatus();
    if (status == null) return BackupFailure(error: 'Estado no encontrado');
    await (update(backupStatusTable)
          ..where((t) => t.id.equals(status.id)))
        .write(BackupStatusTableCompanion(
      lastResult: Value(error),
      lastAttemptAt: Value(DateTime.now()),
      attemptCount: Value(status.attemptCount + 1),
      isRunning: const Value(false),
    ));
    return BackupFailure(error: error);
  }

  Future<void> setBackupRunning() async {
    final status = await getBackupStatus();
    if (status == null) return;
    await (update(backupStatusTable)
          ..where((t) => t.id.equals(status.id)))
        .write(const BackupStatusTableCompanion(isRunning: Value(true)));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'inventario_video.db'));

    return NativeDatabase.createInBackground(file);
  });
}
