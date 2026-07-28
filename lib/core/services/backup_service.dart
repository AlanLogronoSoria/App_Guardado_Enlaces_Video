import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class BackupService {
  final SupabaseClient? _client;

  BackupService() : _client = _initClient();

  static SupabaseClient? _initClient() {
    if (AppConfig.supabaseUrl == 'YOUR_SUPABASE_URL' ||
        AppConfig.supabaseUrl.isEmpty) {
      return null;
    }
    return Supabase.instance.client;
  }

  bool get isConfigured => _client != null;

  Future<String> uploadBackup(String fileName, String jsonContent) async {
    final client = _client;
    if (client == null) {
      throw Exception('El servicio de copias en la nube no está configurado.');
    }

    final bytes = utf8.encode(jsonContent);
    await client.storage
        .from(AppConfig.backupBucketName)
        .uploadBinary(fileName, bytes);

    return fileName;
  }

  Future<String> downloadBackup(String fileName) async {
    final client = _client;
    if (client == null) {
      throw Exception('El servicio de copias en la nube no está configurado.');
    }

    final bytes = await client.storage
        .from(AppConfig.backupBucketName)
        .download(fileName);

    return utf8.decode(bytes);
  }

  Future<List<String>> listBackups() async {
    final client = _client;
    if (client == null) {
      throw Exception('El servicio de copias en la nube no está configurado.');
    }

    final result = await client.storage
        .from(AppConfig.backupBucketName)
        .list();

    return result
        .where((f) => f.name.endsWith('.json'))
        .map((f) => f.name)
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  Future<void> deleteBackup(String fileName) async {
    final client = _client;
    if (client == null) {
      throw Exception('El servicio de copias en la nube no está configurado.');
    }

    await client.storage
        .from(AppConfig.backupBucketName)
        .remove([fileName]);
  }
}
