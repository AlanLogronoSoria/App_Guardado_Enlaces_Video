import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cloud_backup_provider.dart';
import 'ms_oauth_service.dart';

class OneDriveBackupProvider extends CloudBackupProvider {
  final MsOAuthService _auth;
  static const _appFolder = 'Inventario Video';
  static const _backupsFolder = 'Backups';

  String? _appFolderId;
  String? _backupsFolderId;

  OneDriveBackupProvider(this._auth);

  @override
  bool get isAuthenticated => _auth.isAuthenticated;

  @override
  String? get accountEmail => _auth.accountEmail;

  @override
  Future<bool> login() async {
    return _auth.loginDeviceCode();
  }

  @override
  Future<void> logout() async {
    _appFolderId = null;
    _backupsFolderId = null;
    await _auth.logout();
  }

  Future<void> _ensureFolders() async {
    _appFolderId = await _findOrCreateFolder('root', _appFolder);
    if (_appFolderId != null) {
      _backupsFolderId =
          await _findOrCreateFolder(_appFolderId!, _backupsFolder);
    }
  }

  Future<String?> _findOrCreateFolder(
      String parentId, String name) async {
    final token = await _auth.getValidAccessToken();
    if (token == null) return null;

    final search = await http.get(
      Uri.parse(
          "https://graph.microsoft.com/v1.0/me/drive/items/$parentId/children"
          "?\$filter=name eq '$name'"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (search.statusCode == 200) {
      final data = json.decode(search.body);
      final values = data['value'] as List<dynamic>?;
      if (values != null && values.isNotEmpty) {
        return values.first['id'] as String;
      }
    }

    final create = await http.post(
      Uri.parse(
          'https://graph.microsoft.com/v1.0/me/drive/items/$parentId/children'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': name,
        'folder': const <String, dynamic>{},
      }),
    );

    if (create.statusCode == 201) {
      final data = json.decode(create.body);
      return data['id'] as String;
    }

    return null;
  }

  @override
  Future<void> uploadBackup(String fileName, List<int> data) async {
    await _ensureFolders();
    if (_backupsFolderId == null) return;

    final token = await _auth.getValidAccessToken();
    if (token == null) return;

    await http.put(
      Uri.parse(
          "https://graph.microsoft.com/v1.0/me/drive/items/$_backupsFolderId:/$fileName:/content"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
      },
      body: data,
    );
  }

  @override
  Future<List<int>> downloadBackup(String fileName) async {
    await _ensureFolders();
    if (_backupsFolderId == null) return [];

    final token = await _auth.getValidAccessToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse(
          "https://graph.microsoft.com/v1.0/me/drive/items/$_backupsFolderId:/$fileName:/content"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    return [];
  }

  @override
  Future<List<CloudBackupFile>> listBackups() async {
    await _ensureFolders();
    if (_backupsFolderId == null) return [];

    final token = await _auth.getValidAccessToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse(
          "https://graph.microsoft.com/v1.0/me/drive/items/$_backupsFolderId/children"
          "?\$orderby=createdDateTime desc"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final values = data['value'] as List<dynamic>? ?? [];
      return values.map((v) {
        return CloudBackupFile(
          name: v['name'] as String,
          sizeBytes: (v['size'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.tryParse(v['createdDateTime'] as String? ?? '') ??
              DateTime.now(),
        );
      }).toList();
    }

    return [];
  }

  @override
  Future<void> deleteBackup(String fileName) async {
    await _ensureFolders();
    if (_backupsFolderId == null) return;

    final token = await _auth.getValidAccessToken();
    if (token == null) return;

    await http.delete(
      Uri.parse(
          "https://graph.microsoft.com/v1.0/me/drive/items/$_backupsFolderId:/$fileName"),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  void setOnShowCode(void Function(String uri, String code) callback) {
    _auth.setOnShowCode(callback);
  }
}
