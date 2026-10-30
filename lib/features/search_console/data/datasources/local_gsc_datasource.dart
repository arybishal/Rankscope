import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../models/gsc_metric_model.dart';

/// Local SQLite data source for Google Search Console cached metrics.
class LocalGscDatasource {
  final AppDatabase _dbManager;

  LocalGscDatasource({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  Future<int> upsertMetricsBatch(List<GscMetricModel> models) async {
    final db = await _dbManager.database;
    int count = 0;

    await db.transaction((txn) async {
      for (final m in models) {
        await txn.insert(
          DatabaseConstants.tableGscSearchAnalytics,
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });

    return count;
  }

  Future<List<GscMetricModel>> getMetrics(
    int websiteId, {
    String? startDate,
    String? endDate,
    int limit = 100,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = ['website_id = ?'];
    final List<dynamic> whereArgs = [websiteId];

    if (startDate != null) {
      whereClauses.add('metric_date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClauses.add('metric_date <= ?');
      whereArgs.add(endDate);
    }

    final results = await db.query(
      DatabaseConstants.tableGscSearchAnalytics,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'clicks DESC, impressions DESC',
      limit: limit,
    );

    return results.map((m) => GscMetricModel.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getAggregates(
    int websiteId, {
    String? startDate,
    String? endDate,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = ['website_id = ?'];
    final List<dynamic> whereArgs = [websiteId];

    if (startDate != null) {
      whereClauses.add('metric_date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClauses.add('metric_date <= ?');
      whereArgs.add(endDate);
    }

    final query =
        '''
      SELECT 
        SUM(clicks) as total_clicks,
        SUM(impressions) as total_impressions,
        AVG(ctr) as avg_ctr,
        AVG(average_position) as overall_avg_position
      FROM ${DatabaseConstants.tableGscSearchAnalytics}
      WHERE ${whereClauses.join(' AND ')};
    ''';

    final results = await db.rawQuery(query, whereArgs);
    if (results.isEmpty) {
      return {
        'total_clicks': 0,
        'total_impressions': 0,
        'avg_ctr': 0.0,
        'overall_avg_position': 0.0,
      };
    }

    final row = results.first;
    return {
      'total_clicks': row['total_clicks'] as int? ?? 0,
      'total_impressions': row['total_impressions'] as int? ?? 0,
      'avg_ctr': (row['avg_ctr'] as num?)?.toDouble() ?? 0.0,
      'overall_avg_position':
          (row['overall_avg_position'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
