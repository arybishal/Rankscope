import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/repositories/bing_repository.dart';
import '../../domain/utils/bing_property_matcher.dart';
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
        'Retrieved ${sites.length} site(s) from Bing Webmaster API',
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
      throw NetworkFailure('Failed to retrieve sites from Bing: $e');
    }
  }

  @override
  Future<List<BingSiteProperty>> getSiteProperties() async {
    try {
      final properties = await _remoteDatasource.getUserSiteProperties();
      await AppLogger.instance.info(
        'BingRepository',
        'properties_retrieved',
        'Retrieved ${properties.length} property item(s) from Bing Webmaster API',
      );
      return properties;
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
      throw NetworkFailure('Failed to retrieve site properties from Bing: $e');
    }
  }

  @override
  Future<BingPropertyMatchResult> checkPropertyStatus(
    String localDomain,
  ) async {
    try {
      final properties = await _remoteDatasource.getUserSiteProperties();
      return BingPropertyMatcher.match(
        localDomain: localDomain,
        bingProperties: properties,
      );
    } on AuthException catch (e) {
      final msg = e.message;
      if (msg.toLowerCase().contains('not configured')) {
        return BingPropertyMatchResult(
          status: BingVerificationStatus.notConfigured,
          errorMessage: msg,
        );
      }
      return BingPropertyMatchResult(
        status: BingVerificationStatus.authFailed,
        errorMessage: msg,
      );
    } on NetworkException catch (e) {
      return BingPropertyMatchResult(
        status: BingVerificationStatus.connectionUnavailable,
        errorMessage: e.message,
      );
    } catch (e) {
      return BingPropertyMatchResult(
        status: BingVerificationStatus.connectionUnavailable,
        errorMessage: 'Connection failed: $e',
      );
    }
  }

  @override
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
  }) async {
    try {
      // 1. Verify property verification status with Bing account
      final matchResult = await checkPropertyStatus(siteUrl);

      if (!matchResult.isSyncAllowed) {
        switch (matchResult.status) {
          case BingVerificationStatus.notConfigured:
            throw const AuthenticationFailure(
              'Bing API Key is not configured. Please add your key in Settings.',
            );
          case BingVerificationStatus.authFailed:
            throw AuthenticationFailure(
              matchResult.errorMessage ?? 'Bing authentication failed.',
            );
          case BingVerificationStatus.locallyAddedNotVerified:
            throw ValidationFailure(
              'Website "$siteUrl" exists in Bing Webmaster, but domain verification is still pending. Complete verification in the Bing portal.',
            );
          case BingVerificationStatus.propertyNotFound:
            throw ValidationFailure(
              'Website "$siteUrl" was not found in your Bing Webmaster account. Add and verify this property in Bing first.',
            );
          case BingVerificationStatus.connectionUnavailable:
            throw NetworkFailure(
              matchResult.errorMessage ??
                  'Network connection to Bing Webmaster Tools failed.',
            );
          case BingVerificationStatus.verifiedAndMatched:
            break;
        }
      }

      // 2. Use the exact compatible URL returned by Bing Webmaster
      final compatibleTargetUrl = matchResult.matchedBingUrl!;

      // 3. Query stats from Bing API
      final remoteRows = await _remoteDatasource.getQueryStats(
        websiteId: websiteId,
        siteUrl: compatibleTargetUrl,
      );

      if (remoteRows.isEmpty) {
        await AppLogger.instance.info(
          'BingRepository',
          'sync_empty',
          'Bing API returned 0 query stats for $compatibleTargetUrl',
        );
        return 0;
      }

      final count = await _localDatasource.upsertMetricsBatch(remoteRows);
      await AppLogger.instance.info(
        'BingRepository',
        'sync_success',
        'Successfully synced $count Bing query metrics for $compatibleTargetUrl',
      );
      return count;
    } on Failure {
      rethrow;
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
