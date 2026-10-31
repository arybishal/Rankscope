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
import '../../../search_console/domain/utils/gsc_property_matcher.dart';
import '../../../yandex_webmaster/data/repositories/yandex_repository_impl.dart';
import '../../../yandex_webmaster/domain/repositories/yandex_repository.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/rank_observation.dart';

/// Status of Search Performance Synchronization for Google, Bing, and Yandex.
class SearchSyncResult {
  final int totalKeywords;
  final int matchedKeywords;
  final int googleQueriesAvailable;
  final int bingQueriesAvailable;
  final int yandexQueriesAvailable;
  final bool googleConnected;
  final bool bingConnected;
  final bool yandexConnected;
  final String? googleStatusMessage;
  final String? bingStatusMessage;
  final String? yandexStatusMessage;

  const SearchSyncResult({
    required this.totalKeywords,
    required this.matchedKeywords,
    required this.googleQueriesAvailable,
    required this.bingQueriesAvailable,
    this.yandexQueriesAvailable = 0,
    required this.googleConnected,
    required this.bingConnected,
    this.yandexConnected = false,
    this.googleStatusMessage,
    this.bingStatusMessage,
    this.yandexStatusMessage,
  });
}

/// Service that correlates Google Search Console, Bing Webmaster & Yandex Webmaster
/// data with tracked keywords, evaluates Target URL matching, records historical
/// observations, and updates SQLite tables.
class SearchPerformanceSyncService {
  final AppDatabase _dbManager;
  final GscRepository _gscRepository;
  final BingRepository _bingRepository;
  final YandexRepository _yandexRepository;
  final SecureStorageService _secureStorage;

  SearchPerformanceSyncService({
    AppDatabase? dbManager,
    GscRepository? gscRepository,
    BingRepository? bingRepository,
    YandexRepository? yandexRepository,
    SecureStorageService? secureStorage,
  }) : _dbManager = dbManager ?? AppDatabase.instance,
       _gscRepository = gscRepository ?? GscRepositoryImpl(),
       _bingRepository = bingRepository ?? BingRepositoryImpl(),
       _yandexRepository = yandexRepository ?? YandexRepositoryImpl(),
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

  /// Checks if Yandex Webmaster is configured.
  Future<bool> isYandexConfigured() async {
    try {
      final token = await _secureStorage.getYandexOAuthToken();
      return token != null && token.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Synchronizes search engine performance data for the given website and
  /// correlates all saved keywords.
  Future<SearchSyncResult> syncPerformanceForWebsite({
    required int websiteId,
    required String domain,
    String? gscPropertyId,
    String? bingSiteUrl,
    String? yandexHostId,
    String? country,
    String? device,
    String? searchType,
  }) async {
    final db = await _dbManager.database;

    // Lookup website record to ensure we use exact verified properties
    final siteRows = await db.query(
      DatabaseConstants.tableWebsites,
      where: 'id = ?',
      whereArgs: [websiteId],
      limit: 1,
    );
    String? effectiveGscProp = gscPropertyId;
    String? effectiveBingProp = bingSiteUrl;
    String? effectiveYandexProp = yandexHostId;
    if (siteRows.isNotEmpty) {
      final s = siteRows.first;
      effectiveGscProp ??= s['gsc_property_id'] as String?;
      effectiveBingProp ??= s['bing_site_url'] as String?;
      effectiveYandexProp ??= s['yandex_host_id'] as String?;
    }

    bool googleConnected = await isGoogleConfigured();
    bool bingConnected = await isBingConfigured();
    bool yandexConnected = await isYandexConfigured();
    String? googleStatus;
    String? bingStatus;
    String? yandexStatus;

    // 1. Attempt remote fetch for Google Search Console if configured
    if (googleConnected) {
      try {
        final now = DateTime.now();
        final endDate =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final startDate30 = now.subtract(const Duration(days: 30));
        final startDate =
            "${startDate30.year}-${startDate30.month.toString().padLeft(2, '0')}-${startDate30.day.toString().padLeft(2, '0')}";

        // If GSC property not mapped yet, attempt auto-discovery from verified sites
        if (effectiveGscProp == null || effectiveGscProp.isEmpty) {
          try {
            final verifiedSites = await _gscRepository.listVerifiedSites();
            final matched = GscPropertyMatcher.findMatchingProperty(
              domain,
              verifiedSites,
            );
            if (matched != null) {
              effectiveGscProp = matched;
              await db.update(
                DatabaseConstants.tableWebsites,
                {'gsc_property_id': effectiveGscProp},
                where: 'id = ?',
                whereArgs: [websiteId],
              );
            }
          } catch (_) {
            // Non-critical discovery error; proceed to default site URL
          }
        }

        final siteUrl = (effectiveGscProp != null && effectiveGscProp.isNotEmpty)
            ? effectiveGscProp
            : GscPropertyMatcher.defaultSiteUrl(domain);

        int gscCount = 0;
        try {
          gscCount = await _gscRepository.syncMetricsFromApi(
            websiteId: websiteId,
            siteUrl: siteUrl,
            startDate: startDate,
            endDate: endDate,
            country: country,
            device: device,
            searchType: searchType,
          );
        } catch (initialErr) {
          // If the initial site URL failed, attempt domain property / url prefix fallback
          final bare = GscPropertyMatcher.normalizeToBareDomain(domain);
          final altSiteUrl = siteUrl.startsWith('sc-domain:')
              ? 'https://$bare/'
              : 'sc-domain:$bare';
          if (siteUrl != altSiteUrl) {
            gscCount = await _gscRepository.syncMetricsFromApi(
              websiteId: websiteId,
              siteUrl: altSiteUrl,
              startDate: startDate,
              endDate: endDate,
              country: country,
              device: device,
              searchType: searchType,
            );
            effectiveGscProp = altSiteUrl;
            await db.update(
              DatabaseConstants.tableWebsites,
              {'gsc_property_id': altSiteUrl},
              where: 'id = ?',
              whereArgs: [websiteId],
            );
          } else {
            rethrow;
          }
        }

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
        final siteUrl = (effectiveBingProp != null && effectiveBingProp.isNotEmpty)
            ? effectiveBingProp
            : domain;

        final bingCount = await _bingRepository.syncMetricsFromApi(
          websiteId: websiteId,
          siteUrl: siteUrl,
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

    // 3. Attempt remote fetch for Yandex Webmaster if configured
    if (yandexConnected) {
      try {
        // If yandex host not yet mapped, attempt discovery
        if (effectiveYandexProp == null || effectiveYandexProp.isEmpty) {
          try {
            final hosts = await _yandexRepository.getUserHosts();
            final matching = hosts.where((h) {
              final d = h.displayName.toLowerCase();
              final dom = domain.toLowerCase();
              return d.contains(dom) || dom.contains(d);
            }).toList();
            if (matching.isNotEmpty) {
              effectiveYandexProp = matching.first.hostId;
              await db.update(
                DatabaseConstants.tableWebsites,
                {'yandex_host_id': effectiveYandexProp},
                where: 'id = ?',
                whereArgs: [websiteId],
              );
            }
          } catch (_) {}
        }

        if (effectiveYandexProp != null && effectiveYandexProp.isNotEmpty) {
          final now = DateTime.now();
          final endDate =
              "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          final startDate30 = now.subtract(const Duration(days: 30));
          final startDate =
              "${startDate30.year}-${startDate30.month.toString().padLeft(2, '0')}-${startDate30.day.toString().padLeft(2, '0')}";

          final yCount = await _yandexRepository.syncMetricsFromApi(
            websiteId: websiteId,
            hostId: effectiveYandexProp,
            startDate: startDate,
            endDate: endDate,
          );
          yandexStatus = 'Synced $yCount Yandex queries';
        } else {
          yandexStatus = 'No matching verified Yandex host mapped';
        }
      } catch (e) {
        yandexStatus = 'Yandex sync: $e';
        await AppLogger.instance.warning(
          'SearchPerformanceSync',
          'yandex_sync_failed',
          '$e',
        );
      }
    } else {
      yandexStatus = 'Yandex Webmaster not connected';
    }

    // 4. Load all cached search analytics for this website
    final gscRows = await db.query(
      DatabaseConstants.tableGscSearchAnalytics,
      where: 'website_id = ?',
      whereArgs: [websiteId],
      orderBy: 'metric_date DESC, clicks DESC, impressions DESC',
    );

    final bingRows = await db.query(
      DatabaseConstants.tableBingSearchAnalytics,
      where: 'website_id = ?',
      whereArgs: [websiteId],
      orderBy: 'metric_date DESC, clicks DESC, impressions DESC',
    );

    final yandexRows = await db.query(
      DatabaseConstants.tableYandexSearchAnalytics,
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
    if (yandexRows.isNotEmpty && !yandexConnected) {
      yandexStatus = 'Using local Yandex cached data (${yandexRows.length} rows)';
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
      final kwClean = normalizedKw.replaceAll(RegExp(r'[^\w\s]'), '').trim();

      // Find matching GSC metrics for this keyword
      final matchingGsc = gscRows.where((r) {
        final q = (r['query'] as String? ?? '').trim().toLowerCase();
        final qClean = q.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        return q == normalizedKw || (kwClean.isNotEmpty && qClean == kwClean);
      }).toList();

      // Find matching Bing metrics for this keyword
      final matchingBing = bingRows.where((r) {
        final q = (r['query'] as String? ?? '').trim().toLowerCase();
        final qClean = q.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        return q == normalizedKw || (kwClean.isNotEmpty && qClean == kwClean);
      }).toList();

      // Find matching Yandex metrics for this keyword
      final matchingYandex = yandexRows.where((r) {
        final q = (r['query'] as String? ?? '').trim().toLowerCase();
        final qClean = q.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        return q == normalizedKw || (kwClean.isNotEmpty && qClean == kwClean);
      }).toList();

      if (matchingGsc.isEmpty && matchingBing.isEmpty && matchingYandex.isEmpty) {
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
        final bestGsc = matchingGsc.first;
        googleAvgPos = (bestGsc['average_position'] as num?)?.toDouble();
        googleRankingUrl = bestGsc['page_url'] as String?;
        googleSyncedAt = bestGsc['synced_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(bestGsc['synced_at'] as int)
            : now;

        double weightedPosSum = 0.0;
        int weightedImpSum = 0;
        for (final row in matchingGsc) {
          final c = (row['clicks'] as int? ?? 0);
          final imp = (row['impressions'] as int? ?? 0);
          final pos = (row['average_position'] as num?)?.toDouble() ?? 0.0;
          googleClicks += c;
          googleImpressions += imp;
          if (imp > 0 && pos > 0) {
            weightedPosSum += (pos * imp);
            weightedImpSum += imp;
          }
        }
        if (googleImpressions > 0) {
          googleCtr = googleClicks / googleImpressions;
          if (weightedImpSum > 0) {
            googleAvgPos = weightedPosSum / weightedImpSum;
          }
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

      // Aggregate Yandex metrics
      double? yandexAvgPos;
      String? yandexRankingUrl;
      int yandexImpressions = 0;
      int yandexClicks = 0;
      double yandexCtr = 0.0;
      DateTime? yandexSyncedAt;

      if (matchingYandex.isNotEmpty) {
        final bestYandex = matchingYandex.first;
        yandexAvgPos = (bestYandex['average_position'] as num?)?.toDouble();
        yandexRankingUrl = bestYandex['page_url'] as String?;
        yandexSyncedAt = bestYandex['synced_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(bestYandex['synced_at'] as int)
            : now;

        for (final row in matchingYandex) {
          yandexClicks += (row['clicks'] as int? ?? 0);
          yandexImpressions += (row['impressions'] as int? ?? 0);
        }
        if (yandexImpressions > 0) {
          yandexCtr = yandexClicks / yandexImpressions;
        }
      }

      // Determine best observed ranking URL
      final bestRankingUrl =
          googleRankingUrl ?? bingRankingUrl ?? yandexRankingUrl ?? kw.rankingUrl;

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

      // Record Yandex Observation in rank_observations if Yandex data is present
      if (yandexAvgPos != null && yandexAvgPos > 0) {
        await _recordSearchObservationIfNotExists(
          db: db,
          keywordId: kw.id!,
          websiteId: websiteId,
          searchEngine: 'Yandex',
          averagePosition: yandexAvgPos,
          position: yandexAvgPos.round().clamp(1, 100),
          rankingUrl: yandexRankingUrl,
          clicks: yandexClicks,
          impressions: yandexImpressions,
          ctr: yandexCtr,
          recordedAt: yandexSyncedAt ?? now,
          source: 'yandex_api',
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

      if (googleAvgPos != null && googleAvgPos > 0) {
        final newGooglePos = googleAvgPos.round().clamp(1, 100);
        final priorPos = kw.googlePosition;
        final delta = priorPos != null ? (priorPos - newGooglePos) : 0;

        updateMap['google_average_position'] = googleAvgPos;
        updateMap['google_ranking_url'] = googleRankingUrl;
        updateMap['google_impressions'] = googleImpressions;
        updateMap['google_clicks'] = googleClicks;
        updateMap['google_ctr'] = googleCtr;
        updateMap['google_synced_at'] =
            (googleSyncedAt ?? now).millisecondsSinceEpoch;
        updateMap['google_position'] = newGooglePos;
        if (priorPos != null && priorPos != newGooglePos) {
          updateMap['google_previous_position'] = priorPos;
        }
        updateMap['google_delta'] = delta;

        if (kw.latestPosition == null) {
          updateMap['latest_position'] = newGooglePos;
          updateMap['position_delta'] = delta;
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

      if (yandexAvgPos != null) {
        updateMap['yandex_average_position'] = yandexAvgPos;
        updateMap['yandex_ranking_url'] = yandexRankingUrl;
        updateMap['yandex_impressions'] = yandexImpressions;
        updateMap['yandex_clicks'] = yandexClicks;
        updateMap['yandex_ctr'] = yandexCtr;
        updateMap['yandex_synced_at'] =
            (yandexSyncedAt ?? now).millisecondsSinceEpoch;

        if (kw.yandexPosition == null) {
          updateMap['yandex_position'] = yandexAvgPos.round().clamp(1, 100);
        }
        if (kw.latestPosition == null && googleAvgPos == null && bingAvgPos == null) {
          updateMap['latest_position'] = yandexAvgPos.round().clamp(1, 100);
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
      yandexQueriesAvailable: yandexRows.length,
      googleConnected: googleConnected || gscRows.isNotEmpty,
      bingConnected: bingConnected || bingRows.isNotEmpty,
      yandexConnected: yandexConnected || yandexRows.isNotEmpty,
      googleStatusMessage: googleStatus,
      bingStatusMessage: bingStatus,
      yandexStatusMessage: yandexStatus,
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

    // Query matching Yandex rows
    final yandexRows = await db.query(
      DatabaseConstants.tableYandexSearchAnalytics,
      where: 'website_id = ? AND LOWER(TRIM(query)) = ?',
      whereArgs: [keyword.websiteId, normalizedKw],
      orderBy: 'metric_date DESC, clicks DESC',
    );

    if (gscRows.isEmpty && bingRows.isEmpty && yandexRows.isEmpty) {
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

      double weightedPosSum = 0.0;
      int weightedImpSum = 0;
      for (final r in gscRows) {
        final c = (r['clicks'] as int? ?? 0);
        final imp = (r['impressions'] as int? ?? 0);
        final pos = (r['average_position'] as num?)?.toDouble() ?? 0.0;
        googleClicks += c;
        googleImpressions += imp;
        if (imp > 0 && pos > 0) {
          weightedPosSum += (pos * imp);
          weightedImpSum += imp;
        }
      }
      if (googleImpressions > 0) {
        googleCtr = googleClicks / googleImpressions;
        if (weightedImpSum > 0) {
          googleAvgPos = weightedPosSum / weightedImpSum;
        }
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

    // Yandex data
    double? yandexAvgPos;
    String? yandexRankingUrl;
    int yandexImpressions = 0;
    int yandexClicks = 0;
    double yandexCtr = 0.0;
    DateTime? yandexSyncedAt;

    if (yandexRows.isNotEmpty) {
      final best = yandexRows.first;
      yandexAvgPos = (best['average_position'] as num?)?.toDouble();
      yandexRankingUrl = best['page_url'] as String?;
      yandexSyncedAt = best['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(best['synced_at'] as int)
          : now;

      for (final r in yandexRows) {
        yandexClicks += (r['clicks'] as int? ?? 0);
        yandexImpressions += (r['impressions'] as int? ?? 0);
      }
      if (yandexImpressions > 0) {
        yandexCtr = yandexClicks / yandexImpressions;
      }
    }

    final bestRankingUrl =
        googleRankingUrl ?? bingRankingUrl ?? yandexRankingUrl ?? keyword.rankingUrl;
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

    if (yandexAvgPos != null && yandexAvgPos > 0) {
      await _recordSearchObservationIfNotExists(
        db: db,
        keywordId: keyword.id!,
        websiteId: keyword.websiteId,
        searchEngine: 'Yandex',
        averagePosition: yandexAvgPos,
        position: yandexAvgPos.round().clamp(1, 100),
        rankingUrl: yandexRankingUrl,
        clicks: yandexClicks,
        impressions: yandexImpressions,
        ctr: yandexCtr,
        recordedAt: yandexSyncedAt ?? now,
        source: 'yandex_api',
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
      yandexAveragePosition: yandexAvgPos ?? keyword.yandexAveragePosition,
      yandexRankingUrl: yandexRankingUrl ?? keyword.yandexRankingUrl,
      yandexImpressions: yandexImpressions > 0
          ? yandexImpressions
          : keyword.yandexImpressions,
      yandexClicks: yandexClicks > 0 ? yandexClicks : keyword.yandexClicks,
      yandexCtr: yandexCtr > 0 ? yandexCtr : keyword.yandexCtr,
      yandexSyncedAt: yandexSyncedAt ?? keyword.yandexSyncedAt,
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
    final startOfDay = DateTime(
      recordedAt.year,
      recordedAt.month,
      recordedAt.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      recordedAt.year,
      recordedAt.month,
      recordedAt.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final existing = await db.query(
      DatabaseConstants.tableRankObservations,
      where:
          'keyword_id = ? AND search_engine = ? AND source = ? AND recorded_at >= ? AND recorded_at <= ?',
      whereArgs: [
        keywordId,
        searchEngine,
        source,
        startOfDay,
        endOfDay,
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
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      final id = existing.first['id'] as int;
      await db.update(
        DatabaseConstants.tableRankObservations,
        {
          'position': position,
          'average_position': averagePosition,
          'clicks': clicks,
          'impressions': impressions,
          'ctr': ctr,
          'ranking_url': rankingUrl,
          'recorded_at': recordedAt.millisecondsSinceEpoch,
          'observation_status': position > 0 ? 'ranking' : 'not_ranking',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
