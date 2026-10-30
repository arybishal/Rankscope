import '../../../../core/errors/failures.dart';
import '../../domain/entities/gsc_metric.dart';
import '../../domain/repositories/gsc_repository.dart';
import '../datasources/local_gsc_datasource.dart';
import '../datasources/remote_gsc_datasource.dart';

/// Implementation of [GscRepository].
class GscRepositoryImpl implements GscRepository {
  final LocalGscDatasource _localDatasource;
  final RemoteGscDatasource _remoteDatasource;

  GscRepositoryImpl({
    LocalGscDatasource? localDatasource,
    RemoteGscDatasource? remoteDatasource,
  }) : _localDatasource = localDatasource ?? LocalGscDatasource(),
       _remoteDatasource = remoteDatasource ?? RemoteGscDatasource();

  @override
  Future<List<GscMetric>> getMetrics(
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
      throw DatabaseFailure('Failed to load GSC metrics: $e');
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
      throw DatabaseFailure('Failed to compute GSC aggregates: $e');
    }
  }

  @override
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final remoteRows = await _remoteDatasource.querySearchAnalytics(
        websiteId: websiteId,
        siteUrl: siteUrl,
        startDate: startDate,
        endDate: endDate,
      );

      if (remoteRows.isEmpty) return 0;
      return await _localDatasource.upsertMetricsBatch(remoteRows);
    } catch (e) {
      throw NetworkFailure('Failed to synchronize GSC data: $e');
    }
  }
}
