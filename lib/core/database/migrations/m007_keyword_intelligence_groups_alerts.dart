import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 007: Keyword Intelligence Groups & Ranking Alerts
///
/// 1. Creates `keyword_groups` table for organizing keywords into custom groups.
/// 2. Adds `group_id` column to `keywords` table for group association.
/// 3. Creates `ranking_alerts` table to persist triggered ranking alerts and insights.
class M007KeywordIntelligenceGroupsAlerts implements Migration {
  @override
  int get version => 7;

  @override
  String get name => '007_keyword_intelligence_groups_alerts';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    // 1. Create keyword_groups table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS keyword_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        color_hex TEXT,
        description TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_kw_groups_website 
        ON keyword_groups (website_id, name);
    ''');

    // 2. Add group_id to keywords table
    try {
      await db.execute('ALTER TABLE keywords ADD COLUMN group_id INTEGER;');
    } catch (_) {
      // Safe rerun idempotence
    }

    try {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_keywords_group_id 
          ON keywords (group_id);
      ''');
    } catch (_) {}

    // 3. Create ranking_alerts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ranking_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        keyword_id INTEGER,
        alert_type TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'info',
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        search_engine TEXT NOT NULL DEFAULT 'Google',
        details_json TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE,
        FOREIGN KEY (keyword_id) REFERENCES keywords (id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ranking_alerts_website_date 
        ON ranking_alerts (website_id, created_at DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ranking_alerts_keyword 
        ON ranking_alerts (keyword_id);
    ''');
  }
}
