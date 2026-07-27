import '../../database/database.dart';
import '../../shared/models/backup_result.dart';
import '../services/connectivity_service.dart';
import '../repositories/backup_repository.dart';

class BackupScheduler {
  final BackupRepository _backupRepo;
  final ConnectivityService _connectivity;
  final AppDatabase _db;

  static const int daysThreshold = 7;
  static const int modificationsThreshold = 50;

  BackupScheduler(this._backupRepo, this._connectivity, this._db);

  Future<void> tryScheduledBackup() async {
    await _db.ensureBackupStatus();

    final status = await _db.getBackupStatus();
    if (status == null) return;

    if (status.isRunning) return;

    if (!_shouldRun(status)) return;

    final connected = await _connectivity.isConnected();
    if (!connected) return;

    await _db.setBackupRunning();

    try {
      final result = await _backupRepo.createBackup();

      switch (result) {
        case BackupSuccess(:final message, :final fileName):
          await _db.onBackupSuccess(message, fileName ?? '');
        case BackupFailure(:final error):
          await _db.onBackupFailure(error);
        case BackupListSuccess():
          await _db.onBackupFailure('Resultado inesperado.');
      }
    } on Exception catch (e) {
      await _db.onBackupFailure('Error inesperado: $e');
    }
  }

  bool _shouldRun(BackupStatusTableData status) {
    if (status.lastBackupAt == null) return true;

    final daysSinceLast = DateTime.now().difference(status.lastBackupAt!);

    if (daysSinceLast.inDays >= daysThreshold) return true;

    if (status.modificationsSinceLastBackup >= modificationsThreshold) {
      return true;
    }

    return false;
  }
}
