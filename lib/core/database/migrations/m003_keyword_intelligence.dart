import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 003: Adds Search Engine separation, Ranking URL detection,
/// Cannibalization tracking, and the rank_observations historical table.
class M003KeywordIntelligence implements Migration {
  @override
  int get version => 3;

  @override
  String get name => '003_keyword_intelligence';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    // 1. Add keyword intelligence columns to keywords table
    final List<String> columnsToAdd = [
      "ALTER TABLE keywords ADD COLUMN search_engine TEXT NOT NULL DEFAULT 'Google';",
      "ALTER TABLE keywords ADD COLUMN language TEXT NOT NULL DEFAULT 'en';",
      "ALTER TABLE keywords ADD COLUMN device TEXT NOT NULL DEFAULT 'Desktop';",
      "ALTER TABLE keywords ADD COLUMN ranking_url TEXT;",
      "ALTER TABLE keywords ADD COLUMN google_position INTEGER;",
      "ALTER TABLE keywords ADD COLUMN bing_position INTEGER;",
      "ALTER TABLE keywords ADD COLUMN google_previous_position INTEGER;",
      "ALTER TABLE keywords ADD COLUMN bing_previous_position INTEGER;",
      "ALTER TABLE keywords ADD COLUMN google_delta INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN bing_delta INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN cannibalization_status TEXT DEFAULT 'none';",
      "ALTER TABLE keywords ADD COLUMN status_event TEXT DEFAULT 'normal';",
      "ALTER TABLE keywords ADD COLUMN first_ranked_at INTEGER;",
      "ALTER TABLE keywords ADD COLUMN lost_at INTEGER;",
    ];

    for (final sql in columnsToAdd) {
      try {
        await db.execute(sql);
      } catch (_) {
        // Column may already exist if rerun
      }
    }

    // 2. Backfill existing positions to google_position as initial default
    try {
      await db.execute('''
        UPDATE keywords
        SET google_position = latest_position,
            google_previous_position = previous_position,
            google_delta = position_delta
        WHERE google_position IS NULL AND latest_position IS NOT NULL;
      ''');
    } catch (_) {}

    // 3. Create comprehensive rank_observations table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rank_observations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword_id INTEGER NOT NULL,
        website_id INTEGER NOT NULL,
        search_engine TEXT NOT NULL DEFAULT 'Google',
        position INTEGER NOT NULL,
        ranking_url TEXT,
        previous_ranking_url TEXT,
        is_url_change INTEGER NOT NULL DEFAULT 0,
        country TEXT NOT NULL DEFAULT 'GLOBAL',
        language TEXT NOT NULL DEFAULT 'en',
        device TEXT NOT NULL DEFAULT 'Desktop',
        recorded_at INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        observation_status TEXT NOT NULL DEFAULT 'ranking',
        notes TEXT,
        FOREIGN KEY (keyword_id) REFERENCES keywords (id) ON DELETE CASCADE,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rank_obs_kw_engine_date 
        ON rank_observations (keyword_id, search_engine, recorded_at DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rank_obs_website_date 
        ON rank_observations (website_id, recorded_at DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rank_obs_kw_url 
        ON rank_observations (keyword_id, ranking_url);
    ''');

    // 4. Migrate existing manual_rank_records into rank_observations for unified history
    try {
      await db.execute('''
        INSERT INTO rank_observations (
          keyword_id, website_id, search_engine, position,
          ranking_url, country, recorded_at, source, observation_status, notes
        )
        SELECT 
          keyword_id, website_id, search_engine, position,
          ranking_url, location_country, recorded_at, 'manual', 'ranking', notes
        FROM manual_rank_records;
      ''');
    } catch (_) {}
  }
}
