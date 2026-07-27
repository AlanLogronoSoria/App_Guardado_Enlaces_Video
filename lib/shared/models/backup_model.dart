import 'dart:convert';
import 'link.dart';

class BackupModel {
  static const String currentVersion = '1.0.0';
  final String version;
  final DateTime createdAt;
  final List<Map<String, dynamic>> links;
  final List<Map<String, dynamic>> categories;

  const BackupModel({
    required this.version,
    required this.createdAt,
    required this.links,
    required this.categories,
  });

  factory BackupModel.fromData({
    required List<LinkModel> links,
    required List<CategoryModel> categories,
  }) {
    return BackupModel(
      version: currentVersion,
      createdAt: DateTime.now(),
      links: links.map((l) => l.toMap()).toList(),
      categories: categories.map((c) => c.toMap()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'total_links': links.length,
      'total_categories': categories.length,
      'links': links,
      'categories': categories,
    };
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory BackupModel.fromMap(Map<String, dynamic> map) {
    return BackupModel(
      version: map['version'] as String? ?? 'unknown',
      createdAt: _parseDate(map['created_at']),
      links: (map['links'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      categories: (map['categories'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  factory BackupModel.fromJson(String source) =>
      BackupModel.fromMap(json.decode(source) as Map<String, dynamic>);

  List<LinkModel> toLinkModels() =>
      links.map((m) => LinkModel.fromMap(m)).toList();

  List<CategoryModel> toCategoryModels() =>
      categories.map((m) => CategoryModel.fromMap(m)).toList();

  String generateFileName() {
    final date =
        '${createdAt.year}${createdAt.month.toString().padLeft(2, '0')}${createdAt.day.toString().padLeft(2, '0')}';
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}${createdAt.minute.toString().padLeft(2, '0')}${createdAt.second.toString().padLeft(2, '0')}';
    return 'backup_${date}_$time.json';
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
