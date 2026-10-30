import '../entities/bing_metric.dart';
import '../entities/bing_site_property.dart';

export '../entities/bing_metric.dart';
export '../entities/bing_site_property.dart';

/// Repository interface for Bing Webmaster Tools.
abstract class BingRepository {
  Future<List<BingMetric>> getMetrics(int websiteId, {int limit = 100});

  /// Fetches site URLs from Bing Webmaster API using the configured key.
  Future<List<String>> getVerifiedSites();

  /// Fetches rich site properties (including verification status and codes) from Bing API.
  Future<List<BingSiteProperty>> getSiteProperties();

  /// Evaluates local domain against Bing account properties.
  Future<BingPropertyMatchResult> checkPropertyStatus(String localDomain);

  /// Syncs search performance query stats from Bing API into local database.
  /// Only executes when the local domain is confirmed verified in Bing.
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
  });
}
