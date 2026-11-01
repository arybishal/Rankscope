import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/keyword_group.dart';

/// Direct SQLite data source for managing keyword groups and calculating group summaries.
class LocalKeywordGroupsDatasource {
  final AppDatabase _dbManager;

  LocalKeywordGroupsDatasource({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  /// Retrieves all keyword groups for a website, enriched with real-time performance summary metrics.
  Future<List<KeywordGroup>> getGroupsByWebsite(int websiteId) async {
    final db = await _dbManager.database;

    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT 
        g.id,
        g.website_id,
        g.name,
        g.color_hex,
        g.description,
        g.created_at,
        g.updated_at,
        COUNT(k.id) AS keyword_count,
        AVG(CASE 
          WHEN k.google_position IS NOT NULL AND k.google_position > 0 THEN k.google_position 
          WHEN k.latest_position IS NOT NULL AND k.latest_position > 0 THEN k.latest_position 
          ELSE NULL 
        END) AS average_position,
        SUM(COALESCE(k.google_impressions, 0) + COALESCE(k.bing_impressions, 0) + COALESCE(k.yandex_impressions, 0)) AS total_impressions,
        SUM(COALESCE(k.google_clicks, 0) + COALESCE(k.bing_clicks, 0) + COALESCE(k.yandex_clicks, 0)) AS total_clicks
      FROM ${DatabaseConstants.tableKeywordGroups} g
      LEFT JOIN ${DatabaseConstants.tableKeywords} k ON k.group_id = g.id AND k.is_active = 1
      WHERE g.website_id = ?
      GROUP BY g.id
      ORDER BY g.name ASC;
    ''', [websiteId]);

    return rows.map((row) {
      final totalImpressions = (row['total_impressions'] as num?)?.toInt() ?? 0;
      final totalClicks = (row['total_clicks'] as num?)?.toInt() ?? 0;
      final avgCtr = totalImpressions > 0 ? (totalClicks / totalImpressions) : 0.0;

      return KeywordGroup(
        id: row['id'] as int?,
        websiteId: row['website_id'] as int,
        name: row['name'] as String,
        colorHex: row['color_hex'] as String?,
        description: row['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        keywordCount: (row['keyword_count'] as num?)?.toInt() ?? 0,
        averagePosition: (row['average_position'] as num?)?.toDouble(),
        totalImpressions: totalImpressions,
        totalClicks: totalClicks,
        averageCtr: avgCtr,
      );
    }).toList();
  }

  /// Calculates summary metrics for ungrouped keywords of a website.
  Future<KeywordGroup> getUngroupedSummary(int websiteId) async {
    final db = await _dbManager.database;

    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT 
        COUNT(k.id) AS keyword_count,
        AVG(CASE 
          WHEN k.google_position IS NOT NULL AND k.google_position > 0 THEN k.google_position 
          WHEN k.latest_position IS NOT NULL AND k.latest_position > 0 THEN k.latest_position 
          ELSE NULL 
        END) AS average_position,
        SUM(COALESCE(k.google_impressions, 0) + COALESCE(k.bing_impressions, 0) + COALESCE(k.yandex_impressions, 0)) AS total_impressions,
        SUM(COALESCE(k.google_clicks, 0) + COALESCE(k.bing_clicks, 0) + COALESCE(k.yandex_clicks, 0)) AS total_clicks
      FROM ${DatabaseConstants.tableKeywords} k
      WHERE k.website_id = ? AND k.group_id IS NULL AND k.is_active = 1;
    ''', [websiteId]);

    final row = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    final totalImpressions = (row['total_impressions'] as num?)?.toInt() ?? 0;
    final totalClicks = (row['total_clicks'] as num?)?.toInt() ?? 0;
    final avgCtr = totalImpressions > 0 ? (totalClicks / totalImpressions) : 0.0;

    final now = DateTime.now();
    return KeywordGroup(
      id: null,
      websiteId: websiteId,
      name: 'Ungrouped',
      colorHex: '#64748B',
      createdAt: now,
      updatedAt: now,
      keywordCount: (row['keyword_count'] as num?)?.toInt() ?? 0,
      averagePosition: (row['average_position'] as num?)?.toDouble(),
      totalImpressions: totalImpressions,
      totalClicks: totalClicks,
      averageCtr: avgCtr,
    );
  }

  /// Gets a specific group by ID.
  Future<KeywordGroup?> getGroupById(int id) async {
    final db = await _dbManager.database;
    final rows = await db.query(
      DatabaseConstants.tableKeywordGroups,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KeywordGroup.fromMap(rows.first);
  }

  /// Creates a new keyword group.
  Future<KeywordGroup> createGroup(KeywordGroup group) async {
    final db = await _dbManager.database;
    final id = await db.insert(
      DatabaseConstants.tableKeywordGroups,
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return group.copyWith(id: id);
  }

  /// Updates an existing keyword group.
  Future<int> updateGroup(KeywordGroup group) async {
    final db = await _dbManager.database;
    return await db.update(
      DatabaseConstants.tableKeywordGroups,
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  /// Deletes a keyword group and safely sets all associated keywords' group_id to null.
  /// Preserves all keyword ranking observations, notes, and history intact.
  Future<int> deleteGroup(int id) async {
    final db = await _dbManager.database;
    return await db.transaction((txn) async {
      // Unlink keywords from this group
      await txn.update(
        DatabaseConstants.tableKeywords,
        {'group_id': null},
        where: 'group_id = ?',
        whereArgs: [id],
      );

      // Delete group entity
      return await txn.delete(
        DatabaseConstants.tableKeywordGroups,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Moves or assigns a list of keywords to a group (or unassigns if groupId is null).
  Future<void> assignKeywordsToGroup(List<int> keywordIds, int? groupId) async {
    if (keywordIds.isEmpty) return;
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      for (final id in keywordIds) {
        await txn.update(
          DatabaseConstants.tableKeywords,
          {'group_id': groupId},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
