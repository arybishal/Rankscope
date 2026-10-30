import '../entities/gsc_metric.dart';

/// Repository interface for Google Search Console synchronization and querying.
abstract class GscRepository {
  Future<List<GscMetric>> getMetrics(
    int websiteId, {
    String? startDate,
    String? endDate,
    int limit = 100,
  });
  Future<Map<String, dynamic>> getAggregates(
    int websiteId, {
    String? startDate,
    String? endDate,
  });
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
    required String startDate,
    required String endDate,
  });
}
