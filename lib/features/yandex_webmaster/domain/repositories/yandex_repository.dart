import '../entities/yandex_host.dart';
import '../entities/yandex_metric.dart';

abstract class YandexRepository {
  /// Lists verified hosts from Yandex Webmaster.
  Future<List<YandexHost>> getUserHosts();

  /// Retrieves cached metrics from SQLite.
  Future<List<YandexMetric>> getMetrics(
    int websiteId, {
    String? startDate,
    String? endDate,
    int limit = 100,
  });

  /// Computes aggregate metrics from SQLite.
  Future<Map<String, dynamic>> getAggregates(
    int websiteId, {
    String? startDate,
    String? endDate,
  });

  /// Ingests search queries from remote Yandex API and stores in SQLite.
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String hostId,
    String? startDate,
    String? endDate,
  });
}
