import '../entities/bing_metric.dart';

/// Repository interface for Bing Webmaster Tools.
abstract class BingRepository {
  Future<List<BingMetric>> getMetrics(int websiteId, {int limit = 100});

  /// Fetches verified sites from Bing Webmaster API using the configured key.
  Future<List<String>> getVerifiedSites();

  /// Syncs search performance query stats from Bing API into local database.
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
  });
}
