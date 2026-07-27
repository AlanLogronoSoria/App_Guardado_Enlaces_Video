sealed class BackupResult {
  const BackupResult();
}

class BackupSuccess extends BackupResult {
  final String message;
  final String? fileName;
  final DateTime timestamp;

  BackupSuccess({
    required this.message,
    this.fileName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class BackupFailure extends BackupResult {
  final String error;
  final Exception? exception;

  const BackupFailure({
    required this.error,
    this.exception,
  });
}

class BackupListSuccess extends BackupResult {
  final List<String> fileNames;

  const BackupListSuccess({required this.fileNames});
}
