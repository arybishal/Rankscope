import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../bing_webmaster/data/repositories/bing_repository_impl.dart';
import '../../../bing_webmaster/domain/repositories/bing_repository.dart';
import '../../../search_console/data/repositories/gsc_repository_impl.dart';
import '../../../search_console/domain/repositories/gsc_repository.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/rank_observation.dart';

/// Status of Search Performance Synchronization for Google and Bing.
class SearchSyncResult {
  final int totalKeywords;
  final int matchedKeywords;
  final int googleQueriesAvailable;
  final int bingQueriesAvailable;
  final bool googleConnected;
  final bool bingConnected;
  final String? googleStatusMessage;
  final String? bingStatusMessage;

  const SearchSyncResult({
    required this.totalKeywords,
    required this.matchedKeywords,
    required this.googleQueriesAvailable,
    required this.bingQueriesAvailable,
    required this.googleConnected,
    required this.bingConnected,
    this.googleStatusMessage,
    this.bingStatusMessage,
  });
}

/// Service that correlates Google Search Console & Bing Webmaster data with
/// tracked keywords, evaluates Target URL matching, records historical
/// observations, and updates SQLite tables.
class SearchPerformanceSyncService {
  final AppDatabase _dbManager;
  final GscRepository _gscRepository;
  final BingRepository _bingRepository;
  final SecureStorageService _secureStorage;

  SearchPerformanceSyncService({
    AppDatabase? dbManager,
    GscRepository? gscRepository,
    BingRepository? bingRepository,
    SecureStorageService? secureStorage,
  }) : _dbManager = dbManager ?? AppDatabase.instance,
       _gscRepository = gscRepository ?? GscRepositoryImpl(),
       _bingRepository = bingRepository ?? BingRepositoryImpl(),
       _secureStorage = secureStorage ?? SecureStorageService();

  /// Checks if Google Search Console is connected / has credentials.
  Future<bool> isGoogleConfigured() async {
    try {
      final token = await _secureStorage.getGscAccessToken();
      final refresh = await _secureStorage.getGscRefreshToken();
      return (token != null && token.isNotEmpty) ||
          (refresh != null && refresh.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  /// Checks if Bing Webmaster is configured.
  Future<bool> isBingConfigured() async {
    try {
      final key = await _secureStorage.getBingApiKey();
      return key != null && key.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Synchronizes search engine performance data for the given website and
  /// correlates all saved keywords.
  Future<SearchSyncResult> syncPerformanceForWebsite({
    required int websiteId,
    required String domain,
  }) async {
    final db = await _dbManager.database;

    bool googleConnected = await isGoogleConfigured();
    bool bingConnected = await isBingConfigured();
    String? googleStatus;
    String? bingStatus;

    // 1. Attempt remote fetch for Google Search Console if configured
    if (googleConnected) {
      try {
        final now = DateTime.now();
        final endDate =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final startDate30 = now.subtract(const Duration(days: 30));
        final startDate =
            "${startDate30.year}-${startDate30.month.toString().padLeft(2, '0')}-${startDate30.day.toString().padLeft(2, '0')}";

        final gscCount = await _gscRepository.syncMetricsFromApi(
          websiteId: websiteId,
          siteUrl: domain.startsWith('http') ? domain : 'https://$domain/',
          startDate: startDate,
          endDate: endDate,
        );
        googleStatus = 'Synced $gscCount GSC queries';
      } catch (e) {
        googleStatus = 'Google sync: $e';
        await AppLogger.instance.warning(
          'SearchPerformanceSync',
          'gsc_sync_failed',
          '$e',
        );
      }
    } else {
      googleStatus = 'Google Search Console not connected';
    }

    // 2. Attempt remote fetch for Bing Webmaster if configured
    if (bingConnected) {
      try {
        final bingCount = await _bingRepository.syncMetricsFromApi(
          websiteId: websiteId,
          siteUrl: domain,
        );
        bingStatus = 'Synced $bingCount Bing queries';
      } catch (e) {
        bingStatus = 'Bing sync: $e';
        await AppLogger.instance.warning(
          'SearchPerformanceSync',
          'bing_sync_failed',
          '$e',
        );
      }
    } else {
      bingStatus = 'Bing Webmaster API key not configured';
    }

    // 3. Load all cached GSC search analytics for this website
    final gscRows = await db.query(
      DatabaseConstants.tableGscSearchAnalytics,
      where: 'website_id = ?',
      whereArgs: [websiteId],
      orderBy: 'metric_date DESC, clicks DESC, impressions DESC',
    );

    // 4. Load all cached Bing search analytics for this website
    final bingRows = await db.query(
      DatabaseConstants.tableBingSearchAnalytics,
      where: 'website_id = ?',
      whereArgs: [websiteId],
      orderBy: 'metric_date DESC, clicks DESC, impressions DESC',
    );

    // Check if we have any cached data even if remote sync was offline
    if (gscRows.isNotEmpty && !googleConnected) {
      googleStatus = 'Using local GSC cached data (${gscRows.length} rows)';
    }
    if (bingRows.isNotEmpty && !bingConnected) {
      bingStatus = 'Using local Bing cached data (${bingRows.length} rows)';
    }

    // 5. Query all saved keywords for this website
    final kwRows = await db.query(
      DatabaseConstants.tableKeywords,
      where: 'website_id = ?',
      whereArgs: [websiteId],
    );

    final keywords = kwRows.map((m) => Keyword.fromMap(m)).toList();
    int matchedCount = 0;
    final now = DateTime.now();

    for (final kw in keywords) {
      final normalizedKw = kw.keywordText.trim().toLowerCase();

      // Find matching GSC metrics for this keyword
      final matchingGsc = gscRows.where((r) {
        final q = (r['query'] as String? ?? '').trim().toLowerCase();
        return q == normalizedKw;
      }).toList();

      // Find matching Bing metrics for this keyword
      final matchingBing = bingRows.where((r) {
        final q = (r['query'] as String? ?? '').trim().toLowerCase();
        return q == normalizedKw;
      }).toList();

      if (matchingGsc.isEmpty && matchingBing.isEmpty) {
        continue;
      }

      matchedCount++;

      // Aggregate GSC metrics
      double? googleAvgPos;
      String? googleRankingUrl;
      int googleImpressions = 0;
      int googleClicks = 0;
      double googleCtr = 0.0;
      DateTime? googleSyncedAt;

      if (matchingGsc.isNotEmpty) {
        // Pick best row (most recent with highest impressions)
        final bestGsc = matchingGsc.first;
        googleAvgPos = (bestGsc['average_position'] as num?)?.toDouble();
        googleRankingUrl = bestGsc['page_url'] as String?;
        googleSyncedAt = bestGsc['synced_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(bestGsc['synced_at'] as int)
            : now;

        // Sum clicks and impressions across all dates for this query
        for (final row in matchingGsc) {
          googleClicks += (row['clicks'] as int? ?? 0);
          googleImpressions += (row['impressions'] as int? ?? 0);
        }
        if (googleImpressions > 0) {
          googleCtr = googleClicks / googleImpressions;
        }
      }

      // Aggregate Bing metrics
      double? bingAvgPos;
      String? bingRankingUrl;
      int bingImpressions = 0;
      int bingClicks = 0;
      double bingCtr = 0.0;
      DateTime? bingSyncedAt;

      if (matchingBing.isNotEmpty) {
        final bestBing = matchingBing.first;
        bingAvgPos = (bestBing['average_position'] as num?)?.toDouble();
        bingRankingUrl = bestBing['page_url'] as String?;
        bingSyncedAt = bestBing['synced_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(bestBing['synced_at'] as int)
            : now;

        for (final row in matchingBing) {
          bingClicks += (row['clicks'] as int? ?? 0);
          bingImpressions += (row['impressions'] as int? ?? 0);
        }
        if (bingImpressions > 0) {
          bingCtr = bingClicks / bingImpressions;
        }
      }

      // Determine best observed ranking URL
      final bestRankingUrl =
          googleRankingUrl ?? bingRankingUrl ?? kw.rankingUrl;

      // Evaluate Target URL match status
      final matchStatus = UrlValidator.computeUrlMatchStatus(
        kw.targetUrl,
        bestRankingUrl,
      );

      // Record Google Observation in rank_observations if GSC data is present
      if (googleAvgPos != null && googleAvgPos > 0) {
        await _recordSearchObservationIfNotExists(
          db: db,
          keywordId: kw.id!,
          websiteId: websiteId,
          searchEngine: 'Google',
          averagePosition: googleAvgPos,
          position: googleAvgPos.round().clamp(1, 100),
          rankingUrl: googleRankingUrl,
          clicks: googleClicks,
          impressions: googleImpressions,
          ctr: googleCtr,
          recordedAt: googleSyncedAt ?? now,
          source: 'gsc',
        );
      }

      // Record Bing Observation in rank_observations if Bing data is present
      if (bingAvgPos != null && bingAvgPos > 0) {
        await _recordSearchObservationIfNotExists(
          db: db,
          keywordId: kw.id!,
          websiteId: websiteId,
          searchEngine: 'Bing',
          averagePosition: bingAvgPos,
          position: bingAvgPos.round().clamp(1, 100),
          rankingUrl: bingRankingUrl,
          clicks: bingClicks,
          impressions: bingImpressions,
          ctr: bingCtr,
          recordedAt: bingSyncedAt ?? now,
          source: 'bing_api',
        );
      }

      // Update keyword record in SQLite
      final Map<String, dynamic> updateMap = {
        'url_match_status': matchStatus,
        'last_checked_at': now.millisecondsSinceEpoch,
      };

      if (bestRankingUrl != null && bestRankingUrl.isNotEmpty) {
        updateMap['ranking_url'] = bestRankingUrl;
      }

      if (googleAvgPos != null) {
        updateMap['google_average_position'] = googleAvgPos;
        updateMap['google_ranking_url'] = googleRankingUrl;
        updateMap['google_impressions'] = googleImpressions;
        updateMap['google_clicks'] = googleClicks;
        updateMap['google_ctr'] = googleCtr;
        updateMap['google_synced_at'] =
            (googleSyncedAt ?? now).millisecondsSinceEpoch;

        // If manual position was unpopulated or pending, populate it
        if (kw.googlePosition == null) {
          updateMap['google_position'] = googleAvgPos.round().clamp(1, 100);
        }
        if (kw.latestPosition == null) {
          updateMap['latest_position'] = googleAvgPos.round().clamp(1, 100);
        }
      }

      if (bingAvgPos != null) {
        updateMap['bing_average_position'] = bingAvgPos;
        updateMap['bing_ranking_url'] = bingRankingUrl;
        updateMap['bing_impressions'] = bingImpressions;
        updateMap['bing_clicks'] = bingClicks;
        updateMap['bing_ctr'] = bingCtr;
        updateMap['bing_synced_at'] =
            (bingSyncedAt ?? now).millisecondsSinceEpoch;

        if (kw.bingPosition == null) {
          updateMap['bing_position'] = bingAvgPos.round().clamp(1, 100);
        }
        if (kw.latestPosition == null && googleAvgPos == null) {
          updateMap['latest_position'] = bingAvgPos.round().clamp(1, 100);
        }
      }

      await db.update(
        DatabaseConstants.tableKeywords,
        updateMap,
        where: 'id = ?',
        whereArgs: [kw.id],
      );
    }

    return SearchSyncResult(
      totalKeywords: keywords.length,
      matchedKeywords: matchedCount,
      googleQueriesAvailable: gscRows.length,
      bingQueriesAvailable: bingRows.length,
      googleConnected: googleConnected || gscRows.isNotEmpty,
      bingConnected: bingConnected || bingRows.isNotEmpty,
      googleStatusMessage: googleStatus,
      bingStatusMessage: bingStatus,
    );
  }

  /// Immediately correlates a newly added or edited keyword against local
  /// cached Google and Bing metrics.
  Future<Keyword> correlateSingleKeyword(Keyword keyword) async {
    if (keyword.id == null) return keyword;
    final db = await _dbManager.database;
    final normalizedKw = keyword.keywordText.trim().toLowerCase();

    // Query matching GSC rows
    final gscRows = await db.query(
      DatabaseConstants.tableGscSearchAnalytics,
      where: 'website_id = ? AND LOWER(TRIM(query)) = ?',
      whereArgs: [keyword.websiteId, normalizedKw],
      orderBy: 'metric_date DESC, clicks DESC',
    );

    // Query matching Bing rows
    final bingRows = await db.query(
      DatabaseConstants.tableBingSearchAnalytics,
      where: 'website_id = ? AND LOWER(TRIM(query)) = ?',
      whereArgs: [keyword.websiteId, normalizedKw],
      orderBy: 'metric_date DESC, clicks DESC',
    );

    if (gscRows.isEmpty && bingRows.isEmpty) {
      // No search console metrics found yet for this query
      return keyword;
    }

    final now = DateTime.now();

    // GSC data
    double? googleAvgPos;
    String? googleRankingUrl;
    int googleImpressions = 0;
    int googleClicks = 0;
    double googleCtr = 0.0;
    DateTime? googleSyncedAt;

    if (gscRows.isNotEmpty) {
      final best = gscRows.first;
      googleAvgPos = (best['average_position'] as num?)?.toDouble();
      googleRankingUrl = best['page_url'] as String?;
      googleSyncedAt = best['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(best['synced_at'] as int)
          : now;

      for (final r in gscRows) {
        googleClicks += (r['clicks'] as int? ?? 0);
        googleImpressions += (r['impressions'] as int? ?? 0);
      }
      if (googleImpressions > 0) {
        googleCtr = googleClicks / googleImpressions;
      }
    }

    // Bing data
    double? bingAvgPos;
    String? bingRankingUrl;
    int bingImpressions = 0;
    int bingClicks = 0;
    double bingCtr = 0.0;
    DateTime? bingSyncedAt;

    if (bingRows.isNotEmpty) {
      final best = bingRows.first;
      bingAvgPos = (best['average_position'] as num?)?.toDouble();
      bingRankingUrl = best['page_url'] as String?;
      bingSyncedAt = best['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(best['synced_at'] as int)
          : now;

      for (final r in bingRows) {
        bingClicks += (r['clicks'] as int? ?? 0);
        bingImpressions += (r['impressions'] as int? ?? 0);
      }
      if (bingImpressions > 0) {
        bingCtr = bingClicks / bingImpressions;
      }
    }

    final bestRankingUrl =
        googleRankingUrl ?? bingRankingUrl ?? keyword.rankingUrl;
    final matchStatus = UrlValidator.computeUrlMatchStatus(
      keyword.targetUrl,
      bestRankingUrl,
    );

    // Record historical observations
    if (googleAvgPos != null && googleAvgPos > 0) {
      await _recordSearchObservationIfNotExists(
        db: db,
        keywordId: keyword.id!,
        websiteId: keyword.websiteId,
        searchEngine: 'Google',
        averagePosition: googleAvgPos,
        position: googleAvgPos.round().clamp(1, 100),
        rankingUrl: googleRankingUrl,
        clicks: googleClicks,
        impressions: googleImpressions,
        ctr: googleCtr,
        recordedAt: googleSyncedAt ?? now,
        source: 'gsc',
      );
    }

    if (bingAvgPos != null && bingAvgPos > 0) {
      await _recordSearchObservationIfNotExists(
        db: db,
        keywordId: keyword.id!,
        websiteId: keyword.websiteId,
        searchEngine: 'Bing',
        averagePosition: bingAvgPos,
        position: bingAvgPos.round().clamp(1, 100),
        rankingUrl: bingRankingUrl,
        clicks: bingClicks,
        impressions: bingImpressions,
        ctr: bingCtr,
        recordedAt: bingSyncedAt ?? now,
        source: 'bing_api',
      );
    }

    final updatedKeyword = keyword.copyWith(
      rankingUrl: bestRankingUrl,
      googleAveragePosition: googleAvgPos ?? keyword.googleAveragePosition,
      googleRankingUrl: googleRankingUrl ?? keyword.googleRankingUrl,
      googleImpressions: googleImpressions > 0
          ? googleImpressions
          : keyword.googleImpressions,
      googleClicks: googleClicks > 0 ? googleClicks : keyword.googleClicks,
      googleCtr: googleCtr > 0 ? googleCtr : keyword.googleCtr,
      googleSyncedAt: googleSyncedAt ?? keyword.googleSyncedAt,
      bingAveragePosition: bingAvgPos ?? keyword.bingAveragePosition,
      bingRankingUrl: bingRankingUrl ?? keyword.bingRankingUrl,
      bingImpressions: bingImpressions > 0
          ? bingImpressions
          : keyword.bingImpressions,
      bingClicks: bingClicks > 0 ? bingClicks : keyword.bingClicks,
      bingCtr: bingCtr > 0 ? bingCtr : keyword.bingCtr,
      bingSyncedAt: bingSyncedAt ?? keyword.bingSyncedAt,
      urlMatchStatus: matchStatus,
      lastCheckedAt: now,
    );

    await db.update(
      DatabaseConstants.tableKeywords,
      updatedKeyword.toMap(),
      where: 'id = ?',
      whereArgs: [keyword.id],
    );

    return updatedKeyword;
  }

  Future<void> _recordSearchObservationIfNotExists({
    required Database db,
    required int keywordId,
    required int websiteId,
    required String searchEngine,
    required double averagePosition,
    required int position,
    required String? rankingUrl,
    required int clicks,
    required int impressions,
    required double ctr,
    required DateTime recordedAt,
    required String source,
  }) async {
    final existing = await db.query(
      DatabaseConstants.tableRankObservations,
      where: 'keyword_id = ? AND search_engine = ? AND source = ? AND recorded_at = ?',
      whereArgs: [
        keywordId,
        searchEngine,
        source,
        recordedAt.millisecondsSinceEpoch,
      ],
      limit: 1,
    );

    if (existing.isEmpty) {
      final obs = RankObservation(
        keywordId: keywordId,
        websiteId: websiteId,
        searchEngine: searchEngine,
        position: position,
        averagePosition: averagePosition,
        clicks: clicks,
        impressions: impressions,
        ctr: ctr,
        rankingUrl: rankingUrl,
        recordedAt: recordedAt,
        source: source,
        observationStatus: position > 0 ? 'ranking' : 'not_ranking',
      );
      await db.insert(
        DatabaseConstants.tableRankObservations,
        obs.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
