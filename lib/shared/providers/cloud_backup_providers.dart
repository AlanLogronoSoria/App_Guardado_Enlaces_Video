import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud/cloud_backup_provider.dart';
import '../../core/services/cloud/onedrive_backup_provider.dart';
import '../../core/services/cloud/ms_oauth_service.dart';
import '../../core/config/app_config.dart';

final msOAuthProvider = Provider<MsOAuthService>((ref) {
  final service = MsOAuthService(clientId: AppConfig.msClientId);
  service.loadFromStorage();
  return service;
});

final onedriveProvider = Provider<OneDriveBackupProvider>((ref) {
  final auth = ref.watch(msOAuthProvider);
  return OneDriveBackupProvider(auth);
});

final cloudBackupProvider = Provider<CloudBackupProvider>((ref) {
  return ref.watch(onedriveProvider);
});

final cloudAuthStateProvider = StateProvider<bool>((ref) {
  return ref.watch(msOAuthProvider).isAuthenticated;
});
