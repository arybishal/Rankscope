import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../models/manual_rank_record_model.dart';

/// Direct SQLite data source for manual rank records.
class LocalManualRankDatasource {
  final AppDatabase _dbManager;

  LocalManualRankDatasource({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  Future<ManualRankRecordModel> insertRecord(ManualRankRecordModel model) async {
    final db = await _dbManager.database;
    ManualRankRecordModel result = model;

    await db.transaction((txn) async {
      // 1. Fetch current keyword position to calculate delta
      final currentKW = await txn.query(
        DatabaseConstants.tableKeywords,
        columns: ['latest_position'],
        where: 'id = ?',
        whereArgs: [model.keywordId],
      );

      int? oldPos;
      if (currentKW.isNotEmpty && currentKW.first['latest_position'] != null) {
        oldPos = currentKW.first['latest_position'] as int?;
      }

      final int delta = oldPos != null ? (oldPos - model.position) : 0;
      final recordedAtMs = model.recordedAt.millisecondsSinceEpoch;

      // 2. Insert into manual_rank_records
      final id = await txn.insert(
        DatabaseConstants.tableManualRankRecords,
        model.toMap(),
      );
      result = model.copyWith(id: id);

      // 3. Update keywords table
      await txn.update(
        DatabaseConstants.tableKeywords,
        {
          'previous_position': oldPos,
          'latest_position': model.position,
          'position_delta': delta,
          'last_checked_at': recordedAtMs,
        },
        where: 'id = ?',
        whereArgs: [model.keywordId],
      );
    });

    return result;
  }

  Future<List<ManualRankRecordModel>> getHistoryForKeyword(int keywordId, {int limit = 50}) async {
    final db = await _dbManager.database;
    final results = await db.query(
      DatabaseConstants.tableManualRankRecords,
      where: 'keyword_id = ?',
      whereArgs: [keywordId],
      orderBy: 'recorded_at DESC',
      limit: limit,
    );

    return results.map((m) => ManualRankRecordModel.fromMap(m)).toList();
  }

  Future<List<ManualRankRecordModel>> getLatestRecordsForWebsite(int websiteId, {int limit = 100}) async {
    final db = await _dbManager.database;
    final results = await db.query(
      DatabaseConstants.tableManualRankRecords,
      where: 'website_id = ?',
      whereArgs: [websiteId],
      orderBy: 'recorded_at DESC',
      limit: limit,
    );

    return results.map((m) => ManualRankRecordModel.fromMap(m)).toList();
  }

  Future<int> deleteRecord(int recordId) async {
    final db = await _dbManager.database;
    return await db.delete(
      DatabaseConstants.tableManualRankRecords,
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }
}
