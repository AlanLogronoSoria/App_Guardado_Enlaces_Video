import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:inventario_video_app/database/database.dart';
import 'package:inventario_video_app/core/repositories/link_repository.dart';
import 'package:inventario_video_app/core/repositories/category_repository.dart';
import 'package:inventario_video_app/core/services/database_exporter.dart';

void main() {
  late AppDatabase db;
  late LinkRepository linkRepo;
  late CategoryRepository categoryRepo;
  late DatabaseExporter exporter;

  setUp(() {
    db = AppDatabase.forTest(NativeDatabase.memory());
    linkRepo = LinkRepository(db);
    categoryRepo = CategoryRepository(db);
    exporter = DatabaseExporter(linkRepo, categoryRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('DatabaseExporter', () {
    group('exportDatabase() - empty database', () {
      test('produces valid JSON with empty arrays', () async {
        final json = await exporter.exportDatabase();

        expect(_isValidJson(json), isTrue, reason: 'Debe ser JSON válido');

        final parsed = jsonDecode(json) as Map<String, dynamic>;

        expect(parsed.containsKey('metadata'), isTrue);
        expect(parsed.containsKey('categories'), isTrue);
        expect(parsed.containsKey('links'), isTrue);

        final metadata = parsed['metadata'] as Map<String, dynamic>;
        expect(metadata['version'], equals(1));
        expect(metadata['appVersion'], isNotEmpty);
        expect(metadata['createdAt'], isNotEmpty);

        expect(parsed['categories'], isEmpty);
        expect(parsed['links'], isEmpty);
      });
    });

    group('exportDatabase() - with data', () {
      test('exports all categories correctly', () async {
        await categoryRepo.createCategory('Tecnología');
        await categoryRepo.createCategory('Música');
        await categoryRepo.createCategory('Deportes');

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        final categories = parsed['categories'] as List<dynamic>;
        expect(categories.length, equals(3));

        final names =
            categories.map((c) => (c as Map)['name'] as String).toSet();
        expect(names, containsAll(['Tecnología', 'Música', 'Deportes']));
      });

      test('exports all links with all fields', () async {
        await categoryRepo.createCategory('General');
        final link = await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=abc123',
          platform: 'youtube',
          title: 'Video de prueba',
          thumbnail: 'https://img.youtube.com/vi/abc123/hqdefault.jpg',
          category: 'General',
          notes: 'Notas de prueba',
        );

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        final links = parsed['links'] as List<dynamic>;
        expect(links.length, equals(1));

        final exportedLink = links.first as Map<String, dynamic>;
        expect(exportedLink['id'], equals(link.id));
        expect(exportedLink['url'], equals(link.url));
        expect(exportedLink['platform'], equals('youtube'));
        expect(exportedLink['title'], equals('Video de prueba'));
        expect(exportedLink['thumbnail'], equals(link.thumbnail));
        expect(exportedLink['category'], equals('General'));
        expect(exportedLink['favorite'], equals(false));
        expect(exportedLink['notes'], equals('Notas de prueba'));
        expect(exportedLink.containsKey('created_at'), isTrue);
        expect(exportedLink.containsKey('updated_at'), isTrue);
      });

      test('preserves favorite flag', () async {
        await categoryRepo.createCategory('General');
        final saved = await linkRepo.saveLink(
          url: 'https://tiktok.com/@user/video/123',
          platform: 'tiktok',
          title: 'Favorito',
          category: 'General',
        );

        await linkRepo.toggleFavorite(saved.id);

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final links = parsed['links'] as List<dynamic>;
        final exported = links.first as Map<String, dynamic>;

        expect(exported['favorite'], equals(true));
      });

      test('exports links across multiple categories', () async {
        await categoryRepo.createCategory('Música');
        await categoryRepo.createCategory('Deportes');

        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=111',
          platform: 'youtube',
          title: 'Video música',
          category: 'Música',
        );
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=222',
          platform: 'youtube',
          title: 'Video deportes',
          category: 'Deportes',
        );
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=333',
          platform: 'youtube',
          title: 'Video deportes 2',
          category: 'Deportes',
        );

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        final links = parsed['links'] as List<dynamic>;
        expect(links.length, equals(3));

        final categories =
            links.map((l) => (l as Map)['category'] as String).toList();
        expect(categories.where((c) => c == 'Deportes').length, equals(2));
        expect(categories.where((c) => c == 'Música').length, equals(1));
      });

      test('handles special characters in titles', () async {
        await categoryRepo.createCategory('General');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=test',
          platform: 'youtube',
          title: '¡Hola! ¿Cómo estás? ~`!@#\$%^&*()_+-=[]{}\\|;:\'",.<>/?',
          category: 'General',
        );

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final links = parsed['links'] as List<dynamic>;
        final exported = links.first as Map<String, dynamic>;

        expect(exported['title'], contains('¡Hola!'));
        expect(exported['title'], contains('¿Cómo estás?'));
      });

      test('handles null thumbnail and notes', () async {
        await categoryRepo.createCategory('General');
        final link = await linkRepo.saveLink(
          url: 'https://facebook.com/video/123',
          platform: 'facebook',
          title: 'Sin miniatura',
          category: 'General',
        );

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final links = parsed['links'] as List<dynamic>;
        final exported = links.first as Map<String, dynamic>;

        expect(exported['id'], equals(link.id));
        expect(exported['thumbnail'], isNull);
        expect(exported['notes'], isNull);
      });

      test('produces metadata with correct structure', () async {
        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        final metadata = parsed['metadata'] as Map<String, dynamic>;
        expect(metadata.length, equals(3));
        expect(metadata['version'], equals(1));
        expect(metadata['appVersion'], equals('1.0.0+1'));
        expect(metadata['createdAt'], matches(r'^\d{4}-\d{2}-\d{2}T'));
      });

      test('export is deterministic in structure', () async {
        await categoryRepo.createCategory('A');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=1',
          platform: 'youtube',
          title: 'Test',
          category: 'A',
        );

        final first = await exporter.exportDatabase();
        final second = await exporter.exportDatabase();

        final firstParsed = jsonDecode(first) as Map<String, dynamic>;
        final secondParsed = jsonDecode(second) as Map<String, dynamic>;

        expect(
          (firstParsed['links'] as List).length,
          equals((secondParsed['links'] as List).length),
        );
        expect(
          (firstParsed['categories'] as List).length,
          equals((secondParsed['categories'] as List).length),
        );
      });

      test('includes all 10 link fields in each link object', () async {
        await categoryRepo.createCategory('General');
        await linkRepo.saveLink(
          url: 'https://youtube.com/watch?v=fields',
          platform: 'youtube',
          title: 'Campos completos',
          thumbnail: 'https://thumb.jpg',
          category: 'General',
          notes: 'Nota',
        );

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final links = parsed['links'] as List<dynamic>;
        final exported = links.first as Map<String, dynamic>;

        final expectedFields = [
          'id',
          'url',
          'platform',
          'title',
          'thumbnail',
          'category',
          'favorite',
          'notes',
          'created_at',
          'updated_at',
        ];
        for (final field in expectedFields) {
          expect(exported.containsKey(field), isTrue,
              reason: 'Falta el campo: $field');
        }
      });

      test('includes all 3 category fields in each category object',
          () async {
        await categoryRepo.createCategory('Test');

        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final categories = parsed['categories'] as List<dynamic>;
        final exported = categories.first as Map<String, dynamic>;

        final expectedFields = ['id', 'name', 'created_at'];
        for (final field in expectedFields) {
          expect(exported.containsKey(field), isTrue,
              reason: 'Falta el campo: $field');
        }
      });
    });

    group('exportDatabase() - extensibility', () {
      test('metadata can be extended with new fields', () async {
        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        final metadata = parsed['metadata'] as Map<String, dynamic>;
        metadata['futureField'] = 'test';

        expect(metadata['futureField'], equals('test'));
        expect(metadata['version'], equals(1));
      });

      test('export structure supports additional top-level keys', () async {
        final json = await exporter.exportDatabase();
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        parsed['futureSection'] = {'data': []};
        final reEncoded = jsonEncode(parsed);

        expect(_isValidJson(reEncoded), isTrue);
      });
    });
  });
}

bool _isValidJson(String value) {
  try {
    jsonDecode(value);
    return true;
  } catch (_) {
    return false;
  }
}
