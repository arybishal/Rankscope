import '../../../../core/errors/failures.dart';
import '../../domain/entities/manual_rank_record.dart';
import '../../domain/repositories/manual_rank_repository.dart';
import '../datasources/local_manual_rank_datasource.dart';
import '../models/manual_rank_record_model.dart';

/// Implementation of [ManualRankRepository].
class ManualRankRepositoryImpl implements ManualRankRepository {
  final LocalManualRankDatasource _localDatasource;

  ManualRankRepositoryImpl({LocalManualRankDatasource? localDatasource})
    : _localDatasource = localDatasource ?? LocalManualRankDatasource();

  @override
  Future<ManualRankRecord> recordRank(ManualRankRecord record) async {
    try {
      final model = ManualRankRecordModel.fromEntity(record);
      return await _localDatasource.insertRecord(model);
    } catch (e) {
      throw DatabaseFailure('Failed to log rank record: $e');
    }
  }

  @override
  Future<List<ManualRankRecord>> getHistoryForKeyword(
    int keywordId, {
    int limit = 50,
  }) async {
    try {
      return await _localDatasource.getHistoryForKeyword(
        keywordId,
        limit: limit,
      );
    } catch (e) {
      throw DatabaseFailure(
        'Failed to fetch history for keyword #$keywordId: $e',
      );
    }
  }

  @override
  Future<List<ManualRankRecord>> getLatestRecordsForWebsite(
    int websiteId, {
    int limit = 100,
  }) async {
    try {
      return await _localDatasource.getLatestRecordsForWebsite(
        websiteId,
        limit: limit,
      );
    } catch (e) {
      throw DatabaseFailure(
        'Failed to fetch rank records for website #$websiteId: $e',
      );
    }
  }

  @override
  Future<void> deleteRecord(int recordId) async {
    try {
      await _localDatasource.deleteRecord(recordId);
    } catch (e) {
      throw DatabaseFailure('Failed to delete rank record #$recordId: $e');
    }
  }
}
