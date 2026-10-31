import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 005: Adds Yandex Webmaster integration.
/// Adds yandex_host_id to websites, Yandex performance columns to keywords,
/// and creates yandex_search_analytics table.
class M005AddYandexWebmaster implements Migration {
  @override
  int get version => 5;

  @override
  String get name => '005_add_yandex_webmaster';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    // 1. Add yandex_host_id column to websites table
    try {
      await db.execute('ALTER TABLE websites ADD COLUMN yandex_host_id TEXT;');
    } catch (_) {
      // Safe rerun idempotence
    }

    // 2. Add Yandex performance columns to keywords table
    final List<String> keywordColumns = [
      "ALTER TABLE keywords ADD COLUMN yandex_position INTEGER;",
      "ALTER TABLE keywords ADD COLUMN yandex_previous_position INTEGER;",
      "ALTER TABLE keywords ADD COLUMN yandex_delta INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN yandex_average_position REAL;",
      "ALTER TABLE keywords ADD COLUMN yandex_ranking_url TEXT;",
      "ALTER TABLE keywords ADD COLUMN yandex_impressions INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN yandex_clicks INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN yandex_ctr REAL DEFAULT 0.0;",
      "ALTER TABLE keywords ADD COLUMN yandex_synced_at INTEGER;",
    ];

    for (final sql in keywordColumns) {
      try {
        await db.execute(sql);
      } catch (_) {
        // Safe rerun idempotence
      }
    }

    // 3. Create yandex_search_analytics table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS yandex_search_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        query TEXT NOT NULL,
        page_url TEXT,
        device_type TEXT,
        metric_date TEXT NOT NULL,
        clicks INTEGER NOT NULL DEFAULT 0,
        impressions INTEGER NOT NULL DEFAULT 0,
        ctr REAL NOT NULL DEFAULT 0.0,
        average_position REAL NOT NULL DEFAULT 0.0,
        average_click_position REAL,
        synced_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_yandex_web_date 
        ON yandex_search_analytics (website_id, metric_date DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_yandex_query 
        ON yandex_search_analytics (website_id, query);
    ''');
  }
}
