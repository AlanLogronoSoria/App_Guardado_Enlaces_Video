import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:inventario_video_app/database/database.dart';
import 'package:inventario_video_app/core/repositories/link_repository.dart';
import 'package:inventario_video_app/core/repositories/category_repository.dart';
import 'package:inventario_video_app/core/services/database_exporter.dart';
import 'package:inventario_video_app/core/services/database_importer.dart';
import 'package:inventario_video_app/shared/models/backup_result.dart';

void main() {
  late AppDatabase db;
  late LinkRepository linkRepo;
  late CategoryRepository categoryRepo;
  late DatabaseExporter exporter;
  late DatabaseImporter importer;

  setUp(() {
    db = AppDatabase.forTest(NativeDatabase.memory());
    linkRepo = LinkRepository(db);
    categoryRepo = CategoryRepository(db);
    exporter = DatabaseExporter(linkRepo, categoryRepo);
    importer = DatabaseImporter(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DatabaseImporter', () {
    group('restoreDatabase() - validation', () {
      test('rejects empty string', () async {
        final result = await importer.restoreDatabase('');
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('vacío'));
      });

      test('rejects invalid JSON', () async {
        final result = await importer.restoreDatabase('not json');
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('no es válido'));
      });

      test('rejects JSON array instead of object', () async {
        final result = await importer.restoreDatabase('[]');
        expect(result, isA<BackupFailure>());
      });

      test('rejects JSON without categories key', () async {
        final result =
            await importer.restoreDatabase('{"links": []}');
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('categories'));
      });

      test('rejects JSON without links key', () async {
        final result =
            await importer.restoreDatabase('{"categories": []}');
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('links'));
      });

      test('rejects categories that is not a list', () async {
        final result = await importer
            .restoreDatabase('{"categories": "not-a-list", "links": []}');
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('categories'));
      });

      test('rejects links that is not a list', () async {
        final result = await importer.restoreDatabase(
            '{"categories": [], "links": "not-a-list"}');
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('links'));
      });

      test('rejects category without id', () async {
        final result = await importer.restoreDatabase(jsonEncode({
          'categories': [
            {'name': 'Test', 'created_at': '2026-01-01T00:00:00.000'}
          ],
          'links': []
        }));
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('categories'));
      });

      test('rejects category without name', () async {
        final result = await importer.restoreDatabase(jsonEncode({
          'categories': [
            {'id': 'abc', 'created_at': '2026-01-01T00:00:00.000'}
          ],
          'links': []
        }));
        expect(result, isA<BackupFailure>());
      });

      test('rejects link without url', () async {
        final result = await importer.restoreDatabase(jsonEncode({
          'categories': [],
          'links': [
            {
              'id': 'abc',
              'platform': 'youtube',
              'title': 'Test',
              'category': 'General',
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        }));
        expect(result, isA<BackupFailure>());
        expect((result as BackupFailure).error, contains('url'));
      });

      test('rejects link without title', () async {
        final result = await importer.restoreDatabase(jsonEncode({
          'categories': [],
          'links': [
            {
              'id': 'abc',
              'url': 'https://youtube.com',
              'platform': 'youtube',
              'category': 'General',
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        }));
        expect(result, isA<BackupFailure>());
      });

      test('rejects link without created_at', () async {
        final result = await importer.restoreDatabase(jsonEncode({
          'categories': [],
          'links': [
            {
              'id': 'abc',
              'url': 'https://youtube.com',
              'platform': 'youtube',
              'title': 'Test',
              'category': 'General',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        }));
        expect(result, isA<BackupFailure>());
      });
    });

    group('restoreDatabase() - does not modify DB on validation error', () {
      test('existing data survives a failed import', () async {
        await categoryRepo.createCategory('General');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=original',
          platform: 'youtube',
          title: 'Original',
          category: 'General',
        );

        final result = await importer.restoreDatabase('invalid json');
        expect(result, isA<BackupFailure>());

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(1));
        expect(links.first.title, equals('Original'));

        final categories = await categoryRepo.getAllCategories();
        expect(categories.length, equals(1));
        expect(categories.first.name, equals('General'));
      });

      test('existing data survives corrupt link fields', () async {
        await categoryRepo.createCategory('General');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=original',
          platform: 'youtube',
          title: 'Original',
          category: 'General',
        );

        final corruptJson = jsonEncode({
          'categories': [
            {
              'id': 'cat1',
              'name': 'New',
              'created_at': '2026-01-01T00:00:00.000'
            }
          ],
          'links': [
            {'id': 'bad-link'}
          ]
        });

        final result = await importer.restoreDatabase(corruptJson);
        expect(result, isA<BackupFailure>());

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(1));
        expect(links.first.title, equals('Original'));
      });
    });

    group('restoreDatabase() - successful import', () {
      test('imports data from a valid export', () async {
        await categoryRepo.createCategory('Original');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=original',
          platform: 'youtube',
          title: 'Original',
          category: 'Original',
        );

        final exportJson = await exporter.exportDatabase();

        final restoreResult = await importer.restoreDatabase(exportJson);
        expect(restoreResult, isA<BackupSuccess>());

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(1));
        expect(links.first.title, equals('Original'));
        expect(links.first.url, equals('https://youtube.com/watch?v=original'));

        final categories = await categoryRepo.getAllCategories();
        expect(categories.length, equals(1));
        expect(categories.first.name, equals('Original'));
      });

      test('replaces existing data with imported data', () async {
        await categoryRepo.createCategory('Vieja');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=viejo',
          platform: 'youtube',
          title: 'Viejo',
          category: 'Vieja',
        );

        final beforeCount = (await linkRepo.getAllLinks()).length;
        expect(beforeCount, equals(1));

        final importJson = jsonEncode({
          'categories': [
            {
              'id': 'c-new-1',
              'name': 'Nueva',
              'created_at': '2026-06-01T12:00:00.000'
            }
          ],
          'links': [
            {
              'id': 'l-new-1',
              'url': 'https://youtube.com/watch?v=nuevo',
              'platform': 'youtube',
              'title': 'Nuevo',
              'thumbnail': null,
              'category': 'Nueva',
              'favorite': false,
              'notes': null,
              'created_at': '2026-06-01T12:00:00.000',
              'updated_at': '2026-06-01T12:00:00.000'
            }
          ]
        });

        final result = await importer.restoreDatabase(importJson);
        expect(result, isA<BackupSuccess>());

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(1));
        expect(links.first.title, equals('Nuevo'));
        expect(links.first.id, equals('l-new-1'));
        expect(links.first.category, equals('Nueva'));

        final categories = await categoryRepo.getAllCategories();
        expect(categories.length, equals(1));
        expect(categories.first.name, equals('Nueva'));
        expect(categories.first.id, equals('c-new-1'));
      });

      test('preserves original IDs after import', () async {
        final importJson = jsonEncode({
          'categories': [
            {
              'id': 'cat-preserved-id',
              'name': 'Preservada',
              'created_at': '2026-01-01T00:00:00.000'
            }
          ],
          'links': [
            {
              'id': 'link-preserved-id',
              'url': 'https://youtube.com/watch?v=preserved',
              'platform': 'youtube',
              'title': 'Preservado',
              'thumbnail': null,
              'category': 'Preservada',
              'favorite': true,
              'notes': null,
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        });

        await importer.restoreDatabase(importJson);

        final link = await linkRepo.getLinkById('link-preserved-id');
        expect(link, isNotNull);
        expect(link!.id, equals('link-preserved-id'));

        final category =
            await categoryRepo.getCategoryByName('Preservada');
        expect(category, isNotNull);
        expect(category!.id, equals('cat-preserved-id'));
      });

      test('imports empty arrays to clear database', () async {
        await categoryRepo.createCategory('Vieja');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=viejo',
          platform: 'youtube',
          title: 'Viejo',
          category: 'Vieja',
        );

        final emptyJson = jsonEncode({
          'categories': [],
          'links': []
        });

        final result = await importer.restoreDatabase(emptyJson);
        expect(result, isA<BackupSuccess>());

        final links = await linkRepo.getAllLinks();
        expect(links, isEmpty);

        final categories = await categoryRepo.getAllCategories();
        expect(categories, isEmpty);
      });

      test('roundtrip: export -> clear -> import = identical data',
          () async {
        await categoryRepo.createCategory('Música');
        await categoryRepo.createCategory('Deportes');
        final link1 = await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=aaa',
          platform: 'youtube',
          title: 'Link A',
          category: 'Música',
          notes: 'Nota A',
        );
        await linkRepo.toggleFavorite(link1.id);
        await linkRepo.saveLink(
          url: 'https://tiktok.com/@user/video/bbb',
          platform: 'tiktok',
          title: 'Link B',
          category: 'Deportes',
          thumbnail: 'https://thumb.jpg',
        );

        final exportJson = await exporter.exportDatabase();

        await db.deleteAllLinks();
        await db.deleteAllCategories();

        final result = await importer.restoreDatabase(exportJson);
        expect(result, isA<BackupSuccess>());

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(2));

        final link1Restored =
            links.firstWhere((l) => l.id == link1.id);
        expect(link1Restored.title, equals('Link A'));
        expect(link1Restored.favorite, equals(true));
        expect(link1Restored.notes, equals('Nota A'));
        expect(link1Restored.category, equals('Música'));

        final categories = await categoryRepo.getAllCategories();
        expect(categories.length, equals(2));
        expect(
          categories.map((c) => c.name),
          containsAll(['Música', 'Deportes']),
        );
      });

      test('handles multiple categories and links', () async {
        final importJson = jsonEncode({
          'categories': [
            {
              'id': 'c-1',
              'name': 'A',
              'created_at': '2026-01-01T00:00:00.000'
            },
            {
              'id': 'c-2',
              'name': 'B',
              'created_at': '2026-01-02T00:00:00.000'
            }
          ],
          'links': [
            {
              'id': 'l-1',
              'url': 'https://youtube.com/1',
              'platform': 'youtube',
              'title': 'Link 1',
              'thumbnail': null,
              'category': 'A',
              'favorite': false,
              'notes': null,
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            },
            {
              'id': 'l-2',
              'url': 'https://tiktok.com/2',
              'platform': 'tiktok',
              'title': 'Link 2',
              'thumbnail': null,
              'category': 'B',
              'favorite': true,
              'notes': null,
              'created_at': '2026-01-02T00:00:00.000',
              'updated_at': '2026-01-02T00:00:00.000'
            }
          ]
        });

        final result = await importer.restoreDatabase(importJson);
        expect(result, isA<BackupSuccess>());

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(2));
        final names = links.map((l) => l.title).toSet();
        expect(names, containsAll(['Link 1', 'Link 2']));
      });

      test('handles null thumbnail and notes in imported data',
          () async {
        await categoryRepo.createCategory('Vieja');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=con-datos',
          platform: 'youtube',
          title: 'Con datos',
          category: 'Vieja',
          thumbnail: 'https://thumb.jpg',
          notes: 'Nota larga',
        );

        final importJson = jsonEncode({
          'categories': [
            {
              'id': 'c-1',
              'name': 'Nueva',
              'created_at': '2026-01-01T00:00:00.000'
            }
          ],
          'links': [
            {
              'id': 'l-1',
              'url': 'https://youtube.com/sin-datos',
              'platform': 'youtube',
              'title': 'Sin datos',
              'thumbnail': null,
              'category': 'Nueva',
              'favorite': false,
              'notes': null,
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        });

        await importer.restoreDatabase(importJson);

        final links = await linkRepo.getAllLinks();
        expect(links.length, equals(1));
        expect(links.first.thumbnail, isNull);
        expect(links.first.notes, isNull);
      });

      test('restored data is searchable', () async {
        final importJson = jsonEncode({
          'categories': [
            {
              'id': 'c-1',
              'name': 'Tech',
              'created_at': '2026-01-01T00:00:00.000'
            }
          ],
          'links': [
            {
              'id': 'l-1',
              'url': 'https://youtube.com/flutter-tutorial',
              'platform': 'youtube',
              'title': 'Flutter Tutorial Avanzado',
              'thumbnail': null,
              'category': 'Tech',
              'favorite': false,
              'notes': null,
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        });

        await importer.restoreDatabase(importJson);

        final results = await linkRepo.searchLinks('Flutter');
        expect(results.length, equals(1));
        expect(results.first.title, contains('Flutter'));
      });

      test('import preserves boolean favorite correctly', () async {
        final importJson = jsonEncode({
          'categories': [],
          'links': [
            {
              'id': 'l-fav',
              'url': 'https://youtube.com/fav',
              'platform': 'youtube',
              'title': 'Fav',
              'thumbnail': null,
              'category': 'General',
              'favorite': true,
              'notes': null,
              'created_at': '2026-01-01T00:00:00.000',
              'updated_at': '2026-01-01T00:00:00.000'
            }
          ]
        });

        await importer.restoreDatabase(importJson);

        final link = await linkRepo.getLinkById('l-fav');
        expect(link, isNotNull);
        expect(link!.favorite, isTrue);
      });
    });
  });
}
