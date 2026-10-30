import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 002: Add central diagnostic logging table and query indexes.
class M002AddLogsTable implements Migration {
  @override
  int get version => 2;

  @override
  String get name => '002_add_logs_table';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        level TEXT NOT NULL,
        module TEXT NOT NULL,
        event_name TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_logs_timestamp 
        ON app_logs (timestamp DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_logs_level 
        ON app_logs (level);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_logs_module 
        ON app_logs (module);
    ''');
  }
}
