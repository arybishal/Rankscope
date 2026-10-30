/// Database-wide constants, table identifiers, and configuration parameters.
class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'rankscope.db';
  static const int databaseVersion = 2;

  // Table Names
  static const String tableWebsites = 'websites';
  static const String tableKeywords = 'keywords';
  static const String tableManualRankRecords = 'manual_rank_records';
  static const String tableGscSearchAnalytics = 'gsc_search_analytics';
  static const String tableBingSearchAnalytics = 'bing_search_analytics';
  static const String tableCompetitorKeywordLinks = 'competitor_keyword_links';
  static const String tableReportsHistory = 'reports_history';
  static const String tableSchemaMigrations = 'schema_migrations';
  static const String tableAppLogs = 'app_logs';
}
