import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';

/// Entity representing an immutable log record of a synchronization operation.
class SyncHistoryRecord {
  final int? id;
  final int? websiteId;
  final String websiteDomain;
  final String searchEngine; // 'Google', 'Bing', 'Yandex', 'Unified'
  final DateTime startedAt;
  final DateTime completedAt;
  final String status; // 'success', 'partial_success', 'failed', 'skipped'
  final int recordsRetrieved;
  final int matchedKeywords;
  final String? errorDetails;
  final String triggerType; // 'auto', 'manual'
  final DateTime createdAt;

  const SyncHistoryRecord({
    this.id,
    this.websiteId,
    required this.websiteDomain,
    required this.searchEngine,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    this.recordsRetrieved = 0,
    this.matchedKeywords = 0,
    this.errorDetails,
    this.triggerType = 'manual',
    required this.createdAt,
  });

  Duration get duration => completedAt.difference(startedAt);

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'website_id': websiteId,
    'website_domain': websiteDomain,
    'search_engine': searchEngine,
    'started_at': startedAt.millisecondsSinceEpoch,
    'completed_at': completedAt.millisecondsSinceEpoch,
    'status': status,
    'records_retrieved': recordsRetrieved,
    'matched_keywords': matchedKeywords,
    'error_details': errorDetails,
    'trigger_type': triggerType,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory SyncHistoryRecord.fromMap(Map<String, dynamic> map) =>
      SyncHistoryRecord(
        id: map['id'] as int?,
        websiteId: map['website_id'] as int?,
        websiteDomain: map['website_domain'] as String? ?? '',
        searchEngine: map['search_engine'] as String? ?? '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          map['started_at'] as int? ?? 0,
        ),
        completedAt: DateTime.fromMillisecondsSinceEpoch(
          map['completed_at'] as int? ?? 0,
        ),
        status: map['status'] as String? ?? 'success',
        recordsRetrieved: map['records_retrieved'] as int? ?? 0,
        matchedKeywords: map['matched_keywords'] as int? ?? 0,
        errorDetails: map['error_details'] as String?,
        triggerType: map['trigger_type'] as String? ?? 'manual',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int? ?? 0,
        ),
      );
}

/// Datasource for persistent storage and querying of sync audit history in SQLite.
class SyncHistoryDatasource {
  final AppDatabase _dbManager;

  SyncHistoryDatasource({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  Future<int> insertRecord(SyncHistoryRecord record) async {
    final db = await _dbManager.database;
    return await db.insert(
      DatabaseConstants.tableSyncHistory,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncHistoryRecord>> getRecentRecords({
    int limit = 50,
    int? websiteId,
    String? searchEngine,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (websiteId != null) {
      whereClauses.add('website_id = ?');
      whereArgs.add(websiteId);
    }
    if (searchEngine != null && searchEngine.isNotEmpty) {
      whereClauses.add('search_engine = ?');
      whereArgs.add(searchEngine);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      DatabaseConstants.tableSyncHistory,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'completed_at DESC',
      limit: limit,
    );

    return rows.map((m) => SyncHistoryRecord.fromMap(m)).toList();
  }

  Future<int> clearHistory() async {
    final db = await _dbManager.database;
    return await db.delete(DatabaseConstants.tableSyncHistory);
  }
}
