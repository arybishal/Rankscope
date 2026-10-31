import 'package:sqflite/sqflite.dart';

import 'migrations/migration.dart';
import 'migrations/m001_initial_schema.dart';
import 'migrations/m002_add_logs_table.dart';
import 'migrations/m003_keyword_intelligence.dart';
import 'migrations/m004_search_performance_sync.dart';
import 'migrations/m005_add_yandex_webmaster.dart';

/// Registry and orchestrator for database migrations.
class DatabaseMigrations {
  DatabaseMigrations._();

  static final Map<int, Migration> migrations = {
    1: M001InitialSchema(),
    2: M002AddLogsTable(),
    3: M003KeywordIntelligence(),
    4: M004SearchPerformanceSync(),
    5: M005AddYandexWebmaster(),
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
