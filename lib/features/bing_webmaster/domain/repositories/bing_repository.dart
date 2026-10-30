import '../entities/bing_metric.dart';

/// Repository interface for Bing Webmaster Tools.
abstract class BingRepository {
  Future<List<BingMetric>> getMetrics(int websiteId, {int limit = 100});
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
  });
}
