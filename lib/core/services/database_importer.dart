import 'dart:convert';
import 'package:drift/drift.dart';
import '../../database/database.dart';
import '../../shared/models/backup_result.dart';

class DatabaseImporter {
  final AppDatabase _db;

  DatabaseImporter(this._db);

  Future<BackupResult> restoreDatabase(String jsonString) async {
    if (jsonString.trim().isEmpty) {
      return const BackupFailure(error: 'El JSON está vacío.');
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonString) as Map<String, dynamic>;
    } on FormatException {
      return const BackupFailure(error: 'El JSON no es válido.');
    } on TypeError {
      return const BackupFailure(
          error: 'El JSON no tiene la estructura correcta (se esperaba un objeto).');
    }

    final validationError = _validate(parsed);
    if (validationError != null) {
      return BackupFailure(error: validationError);
    }

    final categoriesList = parsed['categories'] as List<dynamic>;
    final linksList = parsed['links'] as List<dynamic>;

    try {
      await _db.transaction(() async {
        await _db.deleteAllLinks();
        await _db.deleteAllCategories();

        for (final cat in categoriesList) {
          final map = Map<String, dynamic>.from(cat as Map);
          await _db.into(_db.categoryTable).insert(
            CategoryTableCompanion(
              id: Value(map['id'] as String),
              name: Value(map['name'] as String),
              createdAt: Value(_parseDateTime(map['created_at'])),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }

        for (final link in linksList) {
          final map = Map<String, dynamic>.from(link as Map);
          await _db.into(_db.linkTable).insert(
            LinkTableCompanion(
              id: Value(map['id'] as String),
              url: Value(map['url'] as String),
              platform: Value(map['platform'] as String),
              title: Value(map['title'] as String),
              thumbnail: Value.absentIfNull(map['thumbnail'] as String?),
              category: Value(map['category'] as String),
              favorite: Value(map['favorite'] == true || map['favorite'] == 1),
              notes: Value.absentIfNull(map['notes'] as String?),
              createdAt: Value(_parseDateTime(map['created_at'])),
              updatedAt: Value(_parseDateTime(map['updated_at'])),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      return BackupSuccess(
        message: 'Restauración completada. '
            '${categoriesList.length} categorías y ${linksList.length} links.',
      );
    } on Exception catch (e) {
      return BackupFailure(
        error: 'Error durante la restauración: $e',
        exception: e,
      );
    }
  }

  String? _validate(Map<String, dynamic> parsed) {
    if (parsed['categories'] == null) {
      return 'Falta la clave "categories" en el JSON.';
    }
    if (parsed['categories'] is! List) {
      return '"categories" debe ser una lista.';
    }
    if (parsed['links'] == null) {
      return 'Falta la clave "links" en el JSON.';
    }
    if (parsed['links'] is! List) {
      return '"links" debe ser una lista.';
    }

    final categoriesList = parsed['categories'] as List;
    final linksList = parsed['links'] as List;

    for (var i = 0; i < categoriesList.length; i++) {
      final cat = categoriesList[i];
      if (cat is! Map) {
        return 'categories[$i] no es un objeto JSON válido.';
      }
      final map = cat;
      if (map['id'] == null || map['id'] is! String) {
        return 'categories[$i] no tiene "id" válido.';
      }
      if (map['name'] == null || map['name'] is! String) {
        return 'categories[$i] no tiene "name" válido.';
      }
      if (map['created_at'] == null) {
        return 'categories[$i] no tiene "created_at".';
      }
    }

    for (var i = 0; i < linksList.length; i++) {
      final link = linksList[i];
      if (link is! Map) {
        return 'links[$i] no es un objeto JSON válido.';
      }
      final map = link;
      if (map['id'] == null || map['id'] is! String) {
        return 'links[$i] no tiene "id" válido.';
      }
      if (map['url'] == null || map['url'] is! String) {
        return 'links[$i] no tiene "url" válido.';
      }
      if (map['platform'] == null || map['platform'] is! String) {
        return 'links[$i] no tiene "platform" válido.';
      }
      if (map['title'] == null || map['title'] is! String) {
        return 'links[$i] no tiene "title" válido.';
      }
      if (map['category'] == null || map['category'] is! String) {
        return 'links[$i] no tiene "category" válido.';
      }
      if (map['created_at'] == null) {
        return 'links[$i] no tiene "created_at".';
      }
      if (map['updated_at'] == null) {
        return 'links[$i] no tiene "updated_at".';
      }
    }

    return null;
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw ArgumentError('No se pudo parsear la fecha: $value');
  }
}
