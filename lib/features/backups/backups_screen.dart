import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../shared/models/backup_result.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/cloud_backup_providers.dart';
import '../../core/services/cloud/cloud_backup_provider.dart';
import '../../core/services/cloud/onedrive_backup_provider.dart';

class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});

  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(backupStatusProvider);
    final countsAsync = ref.watch(backupCountsProvider);
    final isCloudAuth = ref.watch(cloudAuthStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Copias de seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(context, statusAsync, colorScheme),
          const SizedBox(height: 16),
          _buildCountsCard(context, countsAsync, colorScheme),
          const SizedBox(height: 16),
          _buildActionsCard(context, colorScheme),
          const SizedBox(height: 16),
          _buildOneDriveCard(context, isCloudAuth, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOneDriveCard(
      BuildContext context, bool isAuth, ColorScheme colorScheme) {
    final provider = ref.watch(onedriveProvider);
    final email = provider.accountEmail;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: isAuth ? Colors.blue : colorScheme.onSurfaceVariant, size: 22),
                const SizedBox(width: 10),
                Text('OneDrive',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (!isAuth) ...[
              Text('Estado: No conectado',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _startOneDriveAuth(context, provider),
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar sesión con Microsoft'),
                ),
              ),
            ] else ...[
              if (email != null) ...[
                Text('Cuenta: $email',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
              ],
              Text('Estado: Conectado',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: () => _cloudBackup(context, provider),
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Crear Backup'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _cloudRestore(context, provider),
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('Restaurar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showCloudFiles(context, provider),
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('Ver Copias'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await provider.logout();
                    ref.read(cloudAuthStateProvider.notifier).state = false;
                    setState(() {});
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Cerrar sesión'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _startOneDriveAuth(
      BuildContext context, OneDriveBackupProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Iniciar sesión'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Se abrirá una página de Microsoft.'),
            SizedBox(height: 8),
            Text('Ingresa el código que aparece en pantalla '
                'para vincular tu cuenta.',
                style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              provider.setOnShowCode((uri, code) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Vincular cuenta'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('1. Abre este enlace:'),
                        const SizedBox(height: 4),
                        SelectableText(uri,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blue)),
                        const SizedBox(height: 12),
                        const Text('2. Ingresa este código:'),
                        const SizedBox(height: 4),
                        SelectableText(code,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4)),
                        const SizedBox(height: 12),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('Esperando autorización...',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                        },
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                );
              });

              final success = await provider.login();
              if (ctx.mounted) Navigator.of(ctx).pop();

              if (success && context.mounted) {
                ref.read(cloudAuthStateProvider.notifier).state = true;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Sesión iniciada correctamente'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('No se pudo iniciar sesión'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cloudBackup(
      BuildContext context, CloudBackupProvider provider) async {
    final exporter = ref.read(databaseExporterProvider);
    final json = await exporter.exportDatabase();
    final bytes = utf8.encode(json);
    final fileName =
        'backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

    try {
      await provider.uploadBackup(fileName, bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup realizado correctamente'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _cloudRestore(
      BuildContext context, CloudBackupProvider provider) async {
    final files = await provider.listBackups();
    if (!context.mounted) return;

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay backups disponibles')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Seleccionar backup'),
        children: files.map((f) => ListTile(
              title: Text(f.name),
              subtitle: Text(
                  '${(f.sizeBytes / 1024).toStringAsFixed(0)} KB — ${DateFormat('dd/MM/yy').format(f.createdAt)}'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final bytes = await provider.downloadBackup(f.name);
                  final json = utf8.decode(bytes);
                  final importer = ref.read(databaseImporterProvider);
                  await importer.restoreDatabase(json);
                  ref.invalidate(allLinksProvider);
                  ref.invalidate(allCategoriesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Backup restaurado correctamente'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
            )).toList(),
      ),
    );
  }

  void _showCloudFiles(
      BuildContext context, CloudBackupProvider provider) async {
    final files = await provider.listBackups();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Copias en OneDrive'),
        children: files.isEmpty
            ? [const Padding(padding: EdgeInsets.all(16), child: Text('No hay copias'))]
            : files.map((f) => ListTile(
                  title: Text(f.name),
                  subtitle: Text(
                      '${(f.sizeBytes / 1024).toStringAsFixed(0)} KB — ${DateFormat('dd/MM/yy').format(f.createdAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await provider.deleteBackup(f.name);
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${f.name} eliminado'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                )).toList(),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context,
      AsyncValue<BackupStatusTableData?> statusAsync, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text('Estado actual',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            statusAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
              error: (e, _) => Text('Error: $e'),
              data: (status) {
                if (status == null) {
                  return Text('Sin información de respaldo.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(context, 'Último respaldo',
                        status.lastBackupAt != null
                            ? DateFormat('dd/MM/yyyy HH:mm')
                                .format(status.lastBackupAt!)
                            : 'Nunca'),
                    const SizedBox(height: 10),
                    _buildInfoRow(context, 'Cambios sin respaldar',
                        '${status.modificationsSinceLastBackup}'),
                    const SizedBox(height: 10),
                    _buildInfoRow(context, 'Reintentos',
                        '${status.attemptCount}'),
                    if (status.lastResult != null) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(
                          context, 'Último resultado', status.lastResult!),
                    ],
                    if (status.lastAttemptAt != null) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(
                          context,
                          'Último intento',
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(status.lastAttemptAt!)),
                    ],
                    if (status.isRunning) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 4),
                      Text('Respaldando...',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.primary)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountsCard(BuildContext context,
      AsyncValue<({int links, int categories})> countsAsync,
      ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_outlined,
                    color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text('Datos locales',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            countsAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
              error: (e, _) => Text('Error: $e'),
              data: (counts) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildCountTile(
                          context, Icons.videocam_outlined,
                          '${counts.links}', 'Enlaces', colorScheme),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCountTile(
                          context, Icons.folder_outlined,
                          '${counts.categories}', 'Categorías', colorScheme),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountTile(BuildContext context, IconData icon, String count,
      String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          const SizedBox(height: 8),
          Text(count,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildActionsCard(
      BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sync_outlined,
                    color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text('Acciones',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isBackingUp ? null : () => _backupNow(),
              icon: _isBackingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isBackingUp ? 'Respaldando...' : 'Respaldar ahora'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isRestoring
                  ? null
                  : () => _showRestorePicker(context),
              icon: _isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined),
              label:
                  Text(_isRestoring ? 'Restaurando...' : 'Restaurar respaldo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow() async {
    setState(() => _isBackingUp = true);
    final stopwatch = Stopwatch()..start();

    try {
      final result =
          await ref.read(backupRepositoryProvider).createBackup();
      stopwatch.stop();

      if (mounted) {
        final duration = stopwatch.elapsed;

        switch (result) {
          case BackupSuccess(:final message):
            _showResultDialog(context, true, message, duration);
          case BackupFailure(:final error):
            _showResultDialog(context, false, error, duration);
          case BackupListSuccess():
            break;
        }

        ref.invalidate(backupStatusProvider);
        ref.invalidate(backupCountsProvider);
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _showRestorePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar respaldo'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<BackupResult>(
            future: ref.read(backupRepositoryProvider).getBackupList(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final result = snapshot.data;

              if (result == null || result is BackupFailure) {
                return Text(
                  result is BackupFailure
                      ? result.error
                      : 'No se pudieron cargar los respaldos.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                );
              }

              if (result is BackupListSuccess) {
                if (result.fileNames.isEmpty) {
                  return const Text('No hay respaldos disponibles.');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.fileNames.length,
                  itemBuilder: (context, index) {
                    final fileName = result.fileNames[index];
                    return ListTile(
                      leading: const Icon(Icons.cloud_done),
                      title: Text(fileName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        _restoreBackup(fileName);
                      },
                    );
                  },
                );
              }

              return const Text('Error inesperado.');
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(String fileName) async {
    setState(() => _isRestoring = true);
    final stopwatch = Stopwatch()..start();

    try {
      final result = await ref
          .read(backupRepositoryProvider)
          .restoreBackup(fileName);
      stopwatch.stop();

      if (mounted) {
        final duration = stopwatch.elapsed;

        switch (result) {
          case BackupSuccess(:final message):
            _showResultDialog(context, true, message, duration);
          case BackupFailure(:final error):
            _showResultDialog(context, false, error, duration);
          case BackupListSuccess():
            break;
        }

        ref.invalidate(backupStatusProvider);
        ref.invalidate(backupCountsProvider);
        ref.invalidate(allLinksProvider);
        ref.invalidate(allCategoriesProvider);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showResultDialog(BuildContext context, bool success, String message,
      Duration duration) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(success ? 'Éxito' : 'Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Text('Duración: ${_formatDuration(duration)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
