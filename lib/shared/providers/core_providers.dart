import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../core/repositories/link_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/backup_repository.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/openai_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/backup_scheduler.dart';
import '../../core/services/database_exporter.dart';
import '../../core/services/database_importer.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final linkRepositoryProvider = Provider<LinkRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LinkRepository(db);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

final databaseExporterProvider = Provider<DatabaseExporter>((ref) {
  final linkRepo = ref.watch(linkRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  return DatabaseExporter(linkRepo, categoryRepo);
});

final databaseImporterProvider = Provider<DatabaseImporter>((ref) {
  final db = ref.watch(databaseProvider);
  return DatabaseImporter(db);
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final linkRepo = ref.watch(linkRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final backupService = ref.watch(backupServiceProvider);
  final db = ref.watch(databaseProvider);
  return BackupRepository(linkRepo, categoryRepo, backupService, db);
});

final backupSchedulerProvider = Provider<BackupScheduler>((ref) {
  final backupRepo = ref.watch(backupRepositoryProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final db = ref.watch(databaseProvider);
  return BackupScheduler(backupRepo, connectivity, db);
});

final metadataServiceProvider = Provider<MetadataService>((ref) {
  return MetadataService();
});

final openaiServiceProvider = Provider<OpenAIService>((ref) {
  return OpenAIService();
});
