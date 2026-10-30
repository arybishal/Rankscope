import 'package:sqflite/sqflite.dart';

import 'migrations/migration.dart';
import 'migrations/m001_initial_schema.dart';
import 'migrations/m002_add_logs_table.dart';

/// Registry and orchestrator for database migrations.
class DatabaseMigrations {
  DatabaseMigrations._();

  static final Map<int, Migration> migrations = {
    1: M001InitialSchema(),
    2: M002AddLogsTable(),
  };

  /// Executes all migrations needed to bring the database to target version.
  static Future<void> applyMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      final migration = migrations[v];
      if (migration != null) {
        await db.transaction((txn) async {
          await migration.execute(txn);
          await txn.insert('schema_migrations', {
            'version': v,
            'migration_name': migration.name,
            'applied_at': DateTime.now().millisecondsSinceEpoch,
          });
        });
      }
    }
  }
}
