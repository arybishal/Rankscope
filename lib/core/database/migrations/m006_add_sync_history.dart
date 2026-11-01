import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 006: Adds persistent sync history audit log.
class M006AddSyncHistory implements Migration {
  @override
  int get version => 6;

  @override
  String get name => '006_add_sync_history';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER,
        website_domain TEXT NOT NULL,
        search_engine TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        records_retrieved INTEGER DEFAULT 0,
        matched_keywords INTEGER DEFAULT 0,
        error_details TEXT,
        trigger_type TEXT DEFAULT 'manual',
        created_at INTEGER NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_history_website ON sync_history(website_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_history_engine ON sync_history(search_engine);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_history_completed ON sync_history(completed_at DESC);',
    );
  }
}
