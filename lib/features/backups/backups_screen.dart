import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../shared/models/backup_result.dart';
import '../../shared/providers/core_providers.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/link_providers.dart';
import '../../shared/providers/category_providers.dart';

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
        ],
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
