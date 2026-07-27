import 'dart:convert';
import '../config/app_config.dart';
import '../repositories/link_repository.dart';
import '../repositories/category_repository.dart';

class DatabaseExporter {
  final LinkRepository _linkRepo;
  final CategoryRepository _categoryRepo;

  DatabaseExporter(this._linkRepo, this._categoryRepo);

  Future<String> exportDatabase() async {
    final links = await _linkRepo.getAllLinks();
    final categories = await _categoryRepo.getAllCategories();

    final export = <String, dynamic>{
      'metadata': _buildMetadata(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'links': links.map((l) => l.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(export);
  }

  Map<String, dynamic> _buildMetadata() {
    return {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': AppConfig.appVersion,
    };
  }
}
