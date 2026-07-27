import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import 'core_providers.dart';

final backupStatusProvider = FutureProvider<BackupStatusTableData?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getBackupStatus();
});

final backupCountsProvider =
    FutureProvider<({int links, int categories})>((ref) async {
  final db = ref.watch(databaseProvider);
  final linkCount = await db.getLinkCount();
  final categoryCount = await db.getCategoryCount();
  return (links: linkCount, categories: categoryCount);
});
