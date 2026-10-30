import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../models/bing_metric_model.dart';

/// Local SQLite storage for Bing Webmaster metrics.
class LocalBingDatasource {
  final AppDatabase _dbManager;

  LocalBingDatasource({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  Future<int> upsertMetricsBatch(List<BingMetricModel> models) async {
    final db = await _dbManager.database;
    int count = 0;

    await db.transaction((txn) async {
      for (final m in models) {
        await txn.insert(
          DatabaseConstants.tableBingSearchAnalytics,
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });

    return count;
  }

  Future<List<BingMetricModel>> getMetrics(
    int websiteId, {
    int limit = 100,
  }) async {
    final db = await _dbManager.database;
    final results = await db.query(
      DatabaseConstants.tableBingSearchAnalytics,
      where: 'website_id = ?',
      whereArgs: [websiteId],
      orderBy: 'clicks DESC, impressions DESC',
      limit: limit,
    );

    return results.map((m) => BingMetricModel.fromMap(m)).toList();
  }
}
