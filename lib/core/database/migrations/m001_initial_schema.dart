import 'package:sqflite/sqflite.dart';

import 'migration.dart';

/// Migration 001: Initial schema containing all 8 core tables and performance indexes.
class M001InitialSchema implements Migration {
  @override
  int get version => 1;

  @override
  String get name => '001_initial_schema';

  @override
  Future<void> execute(DatabaseExecutor db) async {
    // 1. websites table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS websites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL,
        label TEXT NOT NULL,
        is_competitor INTEGER NOT NULL DEFAULT 0 CHECK (is_competitor IN (0, 1)),
        gsc_property_id TEXT,
        bing_site_url TEXT,
        favicon_url TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_websites_domain_competitor 
        ON websites (domain, is_competitor);
    ''');

    // 2. keywords table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS keywords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        keyword_text TEXT NOT NULL,
        target_url TEXT,
        target_country TEXT NOT NULL DEFAULT 'GLOBAL',
        target_city TEXT,
        tags TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        latest_position INTEGER,
        previous_position INTEGER,
        position_delta INTEGER DEFAULT 0,
        last_checked_at INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_keywords_unique_scope 
        ON keywords (website_id, keyword_text, target_country, target_city);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_keywords_website_active 
        ON keywords (website_id, is_active);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_keywords_latest_pos 
        ON keywords (latest_position);
    ''');

    // 3. manual_rank_records table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS manual_rank_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword_id INTEGER NOT NULL,
        website_id INTEGER NOT NULL,
        position INTEGER NOT NULL CHECK (position >= 1 AND position <= 100),
        ranking_url TEXT,
        search_engine TEXT NOT NULL DEFAULT 'Google' CHECK (search_engine IN ('Google', 'Bing', 'Yahoo', 'DuckDuckGo', 'Other')),
        location_country TEXT NOT NULL DEFAULT 'GLOBAL',
        location_city TEXT,
        serp_features_mask INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        recorded_at INTEGER NOT NULL,
        FOREIGN KEY (keyword_id) REFERENCES keywords (id) ON DELETE CASCADE,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_manual_records_keyword_date 
        ON manual_rank_records (keyword_id, recorded_at DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_manual_records_website_date 
        ON manual_rank_records (website_id, recorded_at DESC);
    ''');

    // 4. gsc_search_analytics table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gsc_search_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        query TEXT NOT NULL,
        page_url TEXT NOT NULL,
        country_code TEXT NOT NULL DEFAULT 'all',
        device_type TEXT NOT NULL DEFAULT 'all' CHECK (device_type IN ('all', 'DESKTOP', 'MOBILE', 'TABLET')),
        metric_date TEXT NOT NULL,
        clicks INTEGER NOT NULL DEFAULT 0,
        impressions INTEGER NOT NULL DEFAULT 0,
        ctr REAL NOT NULL DEFAULT 0.0,
        average_position REAL NOT NULL DEFAULT 0.0,
        synced_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_gsc_unique_record 
        ON gsc_search_analytics (website_id, query, page_url, country_code, device_type, metric_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gsc_query_date 
        ON gsc_search_analytics (website_id, query, metric_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_gsc_metric_date 
        ON gsc_search_analytics (website_id, metric_date);
    ''');

    // 5. bing_search_analytics table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bing_search_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        query TEXT NOT NULL,
        page_url TEXT,
        metric_date TEXT NOT NULL,
        clicks INTEGER NOT NULL DEFAULT 0,
        impressions INTEGER NOT NULL DEFAULT 0,
        ctr REAL NOT NULL DEFAULT 0.0,
        average_position REAL NOT NULL DEFAULT 0.0,
        synced_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bing_unique_record 
        ON bing_search_analytics (website_id, query, metric_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_bing_website_date 
        ON bing_search_analytics (website_id, metric_date);
    ''');

    // 6. competitor_keyword_links table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS competitor_keyword_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        primary_keyword_id INTEGER NOT NULL,
        competitor_keyword_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (primary_keyword_id) REFERENCES keywords (id) ON DELETE CASCADE,
        FOREIGN KEY (competitor_keyword_id) REFERENCES keywords (id) ON DELETE CASCADE,
        CONSTRAINT unique_keyword_pair UNIQUE (primary_keyword_id, competitor_keyword_id)
      );
    ''');

    // 7. reports_history table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reports_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_id INTEGER NOT NULL,
        report_name TEXT NOT NULL,
        report_type TEXT NOT NULL CHECK (report_type IN ('PDF', 'CSV')),
        date_range_start INTEGER NOT NULL,
        date_range_end INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        generated_at INTEGER NOT NULL,
        FOREIGN KEY (website_id) REFERENCES websites (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reports_website 
        ON reports_history (website_id, generated_at DESC);
    ''');

    // 8. schema_migrations table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        migration_name TEXT NOT NULL,
        applied_at INTEGER NOT NULL
      );
    ''');
  }
}
