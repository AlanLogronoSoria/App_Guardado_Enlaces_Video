abstract class CloudBackupProvider {
  Future<bool> login();
  Future<void> logout();
  bool get isAuthenticated;
  String? get accountEmail;

  Future<void> uploadBackup(String fileName, List<int> data);
  Future<List<int>> downloadBackup(String fileName);
  Future<List<CloudBackupFile>> listBackups();
  Future<void> deleteBackup(String fileName);
}

class CloudBackupFile {
  final String name;
  final int sizeBytes;
  final DateTime createdAt;

  const CloudBackupFile({
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
  });
}
