import 'package:drift/drift.dart';

class LinkTable extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get platform => text()();
  TextColumn get title => text()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get category => text()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class BackupStatusTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();
  IntColumn get modificationsSinceLastBackup =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastResult => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  BoolColumn get isRunning => boolean().withDefault(const Constant(false))();
}
