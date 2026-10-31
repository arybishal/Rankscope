import '../../../../core/errors/failures.dart';
import '../../domain/entities/yandex_host.dart';
import '../../domain/entities/yandex_metric.dart';
import '../../domain/repositories/yandex_repository.dart';
import '../datasources/local_yandex_datasource.dart';
import '../datasources/remote_yandex_datasource.dart';

/// Implementation of [YandexRepository].
class YandexRepositoryImpl implements YandexRepository {
  final LocalYandexDatasource _localDatasource;
  final RemoteYandexDatasource _remoteDatasource;

  YandexRepositoryImpl({
    LocalYandexDatasource? localDatasource,
    RemoteYandexDatasource? remoteDatasource,
  }) : _localDatasource = localDatasource ?? LocalYandexDatasource(),
       _remoteDatasource = remoteDatasource ?? RemoteYandexDatasource();

  @override
  Future<List<YandexHost>> getUserHosts() async {
    try {
      return await _remoteDatasource.getUserHosts();
    } catch (e) {
      throw NetworkFailure('Failed to list Yandex hosts: $e');
    }
  }

  @override
  Future<List<YandexMetric>> getMetrics(
    int websiteId, {
    String? startDate,
    String? endDate,
    int limit = 100,
  }) async {
    try {
      return await _localDatasource.getMetrics(
        websiteId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    } catch (e) {
      throw DatabaseFailure('Failed to load Yandex metrics: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getAggregates(
    int websiteId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _localDatasource.getAggregates(
        websiteId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      throw DatabaseFailure('Failed to compute Yandex aggregates: $e');
    }
  }

  @override
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String hostId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final remoteRows = await _remoteDatasource.getPopularQueries(
        websiteId: websiteId,
        hostId: hostId,
        dateFrom: startDate,
        dateTo: endDate,
      );

      if (remoteRows.isEmpty) return 0;
      return await _localDatasource.upsertMetricsBatch(remoteRows);
    } catch (e) {
      throw NetworkFailure('Failed to synchronize Yandex Webmaster data: $e');
    }
  }
}
