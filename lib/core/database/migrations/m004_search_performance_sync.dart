import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 004: Adds Search Console & Bing Search Performance metrics to
/// keywords and rank_observations tables.
///
/// Enables direct correlation between tracked keywords and real search engine
/// performance data (Average Position, Clicks, Impressions, CTR, Ranking URL,
/// and Target URL matching status).
class M004SearchPerformanceSync implements Migration {
  @override
  int get version => 4;

  @override
  String get name => '004_search_performance_sync';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    // 1. Add Search Performance metric columns to keywords table
    final List<String> keywordColumns = [
      "ALTER TABLE keywords ADD COLUMN google_average_position REAL;",
      "ALTER TABLE keywords ADD COLUMN google_ranking_url TEXT;",
      "ALTER TABLE keywords ADD COLUMN google_impressions INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN google_clicks INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN google_ctr REAL DEFAULT 0.0;",
      "ALTER TABLE keywords ADD COLUMN google_synced_at INTEGER;",
      "ALTER TABLE keywords ADD COLUMN bing_average_position REAL;",
      "ALTER TABLE keywords ADD COLUMN bing_ranking_url TEXT;",
      "ALTER TABLE keywords ADD COLUMN bing_impressions INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN bing_clicks INTEGER DEFAULT 0;",
      "ALTER TABLE keywords ADD COLUMN bing_ctr REAL DEFAULT 0.0;",
      "ALTER TABLE keywords ADD COLUMN bing_synced_at INTEGER;",
      "ALTER TABLE keywords ADD COLUMN url_match_status TEXT DEFAULT 'unknown';",
    ];

    for (final sql in keywordColumns) {
      try {
        await db.execute(sql);
      } catch (_) {
        // Safe rerun idempotence
      }
    }

    // 2. Add statistical performance columns to rank_observations table
    final List<String> observationColumns = [
      "ALTER TABLE rank_observations ADD COLUMN average_position REAL;",
      "ALTER TABLE rank_observations ADD COLUMN clicks INTEGER DEFAULT 0;",
      "ALTER TABLE rank_observations ADD COLUMN impressions INTEGER DEFAULT 0;",
      "ALTER TABLE rank_observations ADD COLUMN ctr REAL DEFAULT 0.0;",
      "ALTER TABLE rank_observations ADD COLUMN metric_date TEXT;",
    ];

    for (final sql in observationColumns) {
      try {
        await db.execute(sql);
      } catch (_) {
        // Safe rerun idempotence
      }
    }
  }
}
