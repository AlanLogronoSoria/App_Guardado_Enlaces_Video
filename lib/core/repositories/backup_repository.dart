import 'package:drift/drift.dart';
import '../../database/database.dart';
import '../../shared/models/backup_model.dart';
import '../../shared/models/backup_result.dart';
import '../../core/services/backup_service.dart';
import '../repositories/link_repository.dart';
import '../repositories/category_repository.dart';

class BackupRepository {
  final LinkRepository _linkRepo;
  final CategoryRepository _categoryRepo;
  final BackupService _backupService;
  final AppDatabase _db;

  BackupRepository(
    this._linkRepo,
    this._categoryRepo,
    this._backupService,
    this._db,
  );

  Future<BackupResult> createBackup() async {
    try {
      if (!_backupService.isConfigured) {
        return const BackupFailure(
          error: 'El servicio de copias en la nube no está configurado.',
        );
      }

      final links = await _linkRepo.getAllLinks();
      final categories = await _categoryRepo.getAllCategories();

      if (links.isEmpty && categories.isEmpty) {
        return const BackupFailure(
          error: 'No hay datos para respaldar.',
        );
      }

      final backup = BackupModel.fromData(
        links: links,
        categories: categories,
      );

      final fileName = backup.generateFileName();
      final jsonContent = backup.toJson();

      await _backupService.uploadBackup(fileName, jsonContent);

      final message = 'Respaldo creado exitosamente. '
          '${backup.links.length} links y ${backup.categories.length} categorías.';

      await _db.onBackupSuccess(message, fileName);

      return BackupSuccess(message: message, fileName: fileName);
    } on Exception catch (e) {
      final error = 'Error al crear respaldo: $e';
      await _db.onBackupFailure(error);
      return BackupFailure(error: error, exception: e);
    }
  }

  Future<BackupResult> restoreBackup(String fileName) async {
    try {
      if (!_backupService.isConfigured) {
        return const BackupFailure(
          error: 'El servicio de copias en la nube no está configurado.',
        );
      }

      final jsonContent = await _backupService.downloadBackup(fileName);
      final backup = BackupModel.fromJson(jsonContent);

      if (backup.links.isEmpty && backup.categories.isEmpty) {
        return const BackupFailure(
          error: 'El archivo de respaldo no contiene datos.',
        );
      }

      final linkModels = backup.toLinkModels();
      final categoryModels = backup.toCategoryModels();

      await _db.deleteAllLinks();
      await _db.deleteAllCategories();

      await _db.batchInsertCategoryModels(
        categoryModels.map((c) => CategoryTableCompanion(
              id: Value(c.id),
              name: Value(c.name),
              createdAt: Value(c.createdAt),
            )).toList(),
      );

      await _db.batchInsertLinkModels(
        linkModels.map((l) => LinkTableCompanion(
              id: Value(l.id),
              url: Value(l.url),
              platform: Value(l.platform),
              title: Value(l.title),
              thumbnail: Value.absentIfNull(l.thumbnail),
              category: Value(l.category),
              favorite: Value(l.favorite),
              notes: Value.absentIfNull(l.notes),
              createdAt: Value(l.createdAt),
              updatedAt: Value(l.updatedAt),
            )).toList(),
      );

      return BackupSuccess(
        message: 'Respaldo restaurado exitosamente. '
            '${linkModels.length} links y ${categoryModels.length} categorías.',
        fileName: fileName,
      );
    } on Exception catch (e) {
      return BackupFailure(
        error: 'Error al restaurar respaldo: $e',
        exception: e,
      );
    }
  }

  Future<BackupResult> getBackupList() async {
    try {
      if (!_backupService.isConfigured) {
        return const BackupFailure(
          error: 'El servicio de copias en la nube no está configurado.',
        );
      }

      final fileNames = await _backupService.listBackups();

      if (fileNames.isEmpty) {
        return const BackupFailure(
          error: 'No se encontraron respaldos en la nube.',
        );
      }

      return BackupListSuccess(fileNames: fileNames);
    } on Exception catch (e) {
      return BackupFailure(
        error: 'Error al listar respaldos: $e',
        exception: e,
      );
    }
  }

  Future<BackupResult> deleteRemoteBackup(String fileName) async {
    try {
      if (!_backupService.isConfigured) {
        return const BackupFailure(
          error: 'El servicio de copias en la nube no está configurado.',
        );
      }

      await _backupService.deleteBackup(fileName);

      return BackupSuccess(
        message: 'Respaldo "$fileName" eliminado.',
        fileName: fileName,
      );
    } on Exception catch (e) {
      return BackupFailure(
        error: 'Error al eliminar respaldo: $e',
        exception: e,
      );
    }
  }
}
