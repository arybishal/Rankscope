import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/ranking_alert.dart';

/// Direct SQLite data source for persisting, querying, and managing ranking alerts.
class LocalRankingAlertsDatasource {
  final AppDatabase _dbManager;

  LocalRankingAlertsDatasource({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  /// Fetches ranking alerts for a website with optional filters.
  Future<List<RankingAlert>> getAlertsByWebsite(
    int websiteId, {
    bool? unreadOnly,
    String? alertType,
    String? severity,
    int limit = 100,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = ['website_id = ?'];
    final List<dynamic> whereArgs = [websiteId];

    if (unreadOnly == true) {
      whereClauses.add('is_read = 0');
    }

    if (alertType != null && alertType.isNotEmpty && alertType != 'all') {
      whereClauses.add('alert_type = ?');
      whereArgs.add(alertType);
    }

    if (severity != null && severity.isNotEmpty && severity != 'all') {
      whereClauses.add('severity = ?');
      whereArgs.add(severity);
    }

    final rows = await db.query(
      DatabaseConstants.tableRankingAlerts,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map((r) => RankingAlert.fromMap(r)).toList();
  }

  /// Inserts a new ranking alert.
  Future<RankingAlert> insertAlert(RankingAlert alert) async {
    final db = await _dbManager.database;
    final id = await db.insert(
      DatabaseConstants.tableRankingAlerts,
      alert.toMap(),
    );
    return alert.copyWith(id: id);
  }

  /// Inserts a batch of ranking alerts.
  Future<List<RankingAlert>> insertAlertsBatch(List<RankingAlert> alerts) async {
    if (alerts.isEmpty) return [];
    final db = await _dbManager.database;
    final List<RankingAlert> inserted = [];

    await db.transaction((txn) async {
      for (final alert in alerts) {
        final id = await txn.insert(
          DatabaseConstants.tableRankingAlerts,
          alert.toMap(),
        );
        inserted.add(alert.copyWith(id: id));
      }
    });

    return inserted;
  }

  /// Marks a specific alert as read.
  Future<void> markAsRead(int alertId) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseConstants.tableRankingAlerts,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  /// Marks all alerts for a website as read.
  Future<void> markAllAsRead(int websiteId) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseConstants.tableRankingAlerts,
      {'is_read': 1},
      where: 'website_id = ? AND is_read = 0',
      whereArgs: [websiteId],
    );
  }

  /// Deletes a specific alert.
  Future<int> deleteAlert(int alertId) async {
    final db = await _dbManager.database;
    return await db.delete(
      DatabaseConstants.tableRankingAlerts,
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  /// Clears all alerts for a website.
  Future<int> clearAlerts(int websiteId) async {
    final db = await _dbManager.database;
    return await db.delete(
      DatabaseConstants.tableRankingAlerts,
      where: 'website_id = ?',
      whereArgs: [websiteId],
    );
  }

  /// Returns count of unread alerts for a website.
  Future<int> getUnreadCount(int websiteId) async {
    final db = await _dbManager.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableRankingAlerts} WHERE website_id = ? AND is_read = 0',
      [websiteId],
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }
}
