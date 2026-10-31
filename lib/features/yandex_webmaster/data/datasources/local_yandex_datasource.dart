import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/yandex_metric.dart';
import '../models/yandex_metric_model.dart';

/// Local SQLite data source for Yandex Webmaster analytics.
class LocalYandexDatasource {
  final AppDatabase _dbManager;

  LocalYandexDatasource({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  /// Ingests a batch of Yandex metrics, updating existing rows or inserting new ones.
  Future<int> upsertMetricsBatch(List<YandexMetricModel> metrics) async {
    if (metrics.isEmpty) return 0;
    final db = await _dbManager.database;

    int affectedCount = 0;
    await db.transaction((txn) async {
      for (final m in metrics) {
        final existing = await txn.query(
          DatabaseConstants.tableYandexSearchAnalytics,
          where: 'website_id = ? AND query = ? AND metric_date = ?',
          whereArgs: [m.websiteId, m.query, m.metricDate],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await txn.update(
            DatabaseConstants.tableYandexSearchAnalytics,
            {
              'clicks': m.clicks,
              'impressions': m.impressions,
              'ctr': m.ctr,
              'average_position': m.averagePosition,
              'average_click_position': m.averageClickPosition,
              'synced_at': m.syncedAt.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.insert(
            DatabaseConstants.tableYandexSearchAnalytics,
            m.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        affectedCount++;
      }
    });

    return affectedCount;
  }

  /// Retrieves cached Yandex metrics for a website.
  Future<List<YandexMetric>> getMetrics(
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

    final rows = await db.query(
      DatabaseConstants.tableYandexSearchAnalytics,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'metric_date DESC, impressions DESC, clicks DESC',
      limit: limit,
    );

    return rows.map((r) => YandexMetric.fromMap(r)).toList();
  }

  /// Calculates aggregate metrics for Yandex data.
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

    final rows = await db.query(
      DatabaseConstants.tableYandexSearchAnalytics,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
    );

    if (rows.isEmpty) {
      return {
        'total_clicks': 0,
        'total_impressions': 0,
        'average_ctr': 0.0,
        'average_position': 0.0,
        'queries_count': 0,
      };
    }

    int totalClicks = 0;
    int totalImpressions = 0;
    double posSumWeighted = 0.0;

    for (final r in rows) {
      final clicks = r['clicks'] as int? ?? 0;
      final impressions = r['impressions'] as int? ?? 0;
      final avgPos = (r['average_position'] as num?)?.toDouble() ?? 0.0;

      totalClicks += clicks;
      totalImpressions += impressions;
      posSumWeighted += avgPos * (impressions > 0 ? impressions : 1);
    }

    final double avgCtr = totalImpressions > 0 ? (totalClicks / totalImpressions) : 0.0;
    final double avgPos = totalImpressions > 0
        ? (posSumWeighted / totalImpressions)
        : 0.0;

    return {
      'total_clicks': totalClicks,
      'total_impressions': totalImpressions,
      'average_ctr': avgCtr,
      'average_position': avgPos,
      'queries_count': rows.length,
    };
  }

  /// Deletes cached metrics for a website.
  Future<void> clearMetricsForWebsite(int websiteId) async {
    final db = await _dbManager.database;
    await db.delete(
      DatabaseConstants.tableYandexSearchAnalytics,
      where: 'website_id = ?',
      whereArgs: [websiteId],
    );
  }
}
