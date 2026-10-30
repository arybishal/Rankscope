import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/bing_metric.dart';
import '../../domain/repositories/bing_repository.dart';
import '../datasources/local_bing_datasource.dart';
import '../datasources/remote_bing_datasource.dart';

/// Implementation of [BingRepository].
class BingRepositoryImpl implements BingRepository {
  final LocalBingDatasource _localDatasource;
  final RemoteBingDatasource _remoteDatasource;

  BingRepositoryImpl({
    LocalBingDatasource? localDatasource,
    RemoteBingDatasource? remoteDatasource,
  }) : _localDatasource = localDatasource ?? LocalBingDatasource(),
       _remoteDatasource = remoteDatasource ?? RemoteBingDatasource();

  @override
  Future<List<BingMetric>> getMetrics(int websiteId, {int limit = 100}) async {
    try {
      return await _localDatasource.getMetrics(websiteId, limit: limit);
    } catch (e) {
      throw DatabaseFailure('Failed to load Bing metrics: $e');
    }
  }

  @override
  Future<List<String>> getVerifiedSites() async {
    try {
      final sites = await _remoteDatasource.getUserSites();
      await AppLogger.instance.info(
        'BingRepository',
        'sites_retrieved',
        'Retrieved ${sites.length} verified site(s) from Bing Webmaster API',
      );
      return sites;
    } on AuthException catch (e) {
      await AppLogger.instance.warning(
        'BingRepository',
        'auth_failed',
        e.message,
      );
      throw AuthenticationFailure(e.message);
    } on NetworkException catch (e) {
      await AppLogger.instance.error(
        'BingRepository',
        'network_failed',
        e.message,
      );
      throw NetworkFailure(e.message);
    } catch (e) {
      await AppLogger.instance.error(
        'BingRepository',
        'unexpected_error',
        '$e',
      );
      throw NetworkFailure('Failed to retrieve verified sites from Bing: $e');
    }
  }

  @override
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
  }) async {
    try {
      // 1. Retrieve registered sites from Bing account to find canonical match
      final verifiedSites = await _remoteDatasource.getUserSites();

      final normalizedTarget = siteUrl
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .replaceAll('/', '')
          .trim()
          .toLowerCase();

      String? matchedUrl;
      for (final s in verifiedSites) {
        final normalizedS = s
            .replaceAll('https://', '')
            .replaceAll('http://', '')
            .replaceAll('/', '')
            .trim()
            .toLowerCase();
        if (normalizedS == normalizedTarget ||
            normalizedS == 'www.$normalizedTarget' ||
            'www.$normalizedS' == normalizedTarget) {
          matchedUrl = s;
          break;
        }
      }

      // If matched, use the exact registered URL in Bing; otherwise fallback to HTTPS
      final targetUrl =
          matchedUrl ??
          (siteUrl.startsWith('http') ? siteUrl : 'https://$siteUrl/');

      // 2. Query stats from Bing API
      final remoteRows = await _remoteDatasource.getQueryStats(
        websiteId: websiteId,
        siteUrl: targetUrl,
      );

      if (remoteRows.isEmpty) {
        await AppLogger.instance.info(
          'BingRepository',
          'sync_empty',
          'Bing API returned 0 query stats for $targetUrl',
        );
        return 0;
      }

      final count = await _localDatasource.upsertMetricsBatch(remoteRows);
      await AppLogger.instance.info(
        'BingRepository',
        'sync_success',
        'Successfully synced $count Bing query metrics for $targetUrl',
      );
      return count;
    } on AuthException catch (e) {
      await AppLogger.instance.warning(
        'BingRepository',
        'sync_auth_failed',
        e.message,
      );
      throw AuthenticationFailure(e.message);
    } on NetworkException catch (e) {
      await AppLogger.instance.error(
        'BingRepository',
        'sync_network_failed',
        e.message,
      );
      throw NetworkFailure(e.message);
    } catch (e) {
      await AppLogger.instance.error('BingRepository', 'sync_failed', '$e');
      throw NetworkFailure('Failed to sync Bing data: $e');
    }
  }
}
