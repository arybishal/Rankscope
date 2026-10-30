import '../../../../core/errors/failures.dart';
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
  })  : _localDatasource = localDatasource ?? LocalBingDatasource(),
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
  Future<int> syncMetricsFromApi({required int websiteId, required String siteUrl}) async {
    try {
      final remoteRows = await _remoteDatasource.getQueryStats(
        websiteId: websiteId,
        siteUrl: siteUrl,
      );

      if (remoteRows.isEmpty) return 0;
      return await _localDatasource.upsertMetricsBatch(remoteRows);
    } catch (e) {
      throw NetworkFailure('Failed to sync Bing data: $e');
    }
  }
}
