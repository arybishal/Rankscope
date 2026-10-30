import '../entities/manual_rank_record.dart';

/// Repository contract for logging and reading manual SERP rank records.
abstract class ManualRankRepository {
  Future<ManualRankRecord> recordRank(ManualRankRecord record);
  Future<List<ManualRankRecord>> getHistoryForKeyword(
    int keywordId, {
    int limit = 50,
  });
  Future<List<ManualRankRecord>> getLatestRecordsForWebsite(
    int websiteId, {
    int limit = 100,
  });
  Future<void> deleteRecord(int recordId);
}
