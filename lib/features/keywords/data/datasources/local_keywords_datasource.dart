import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/rank_observation.dart';

/// Direct SQLite data source for keyword records and rank observations.
class LocalKeywordsDatasource {
  final AppDatabase _dbManager;

  LocalKeywordsDatasource({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? searchEngine,
    String? tag,
    int? groupId,
    bool onlyUngrouped = false,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = ['website_id = ?'];
    final List<dynamic> whereArgs = [websiteId];

    if (isActive != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(isActive ? 1 : 0);
    }

    if (searchEngine != null && searchEngine.toLowerCase() != 'all') {
      whereClauses.add('search_engine = ?');
      whereArgs.add(searchEngine);
    }

    if (tag != null && tag.isNotEmpty) {
      whereClauses.add('tags LIKE ?');
      whereArgs.add('%$tag%');
    }

    if (onlyUngrouped) {
      whereClauses.add('group_id IS NULL');
    } else if (groupId != null) {
      whereClauses.add('group_id = ?');
      whereArgs.add(groupId);
    }

    final results = await db.query(
      DatabaseConstants.tableKeywords,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'latest_position IS NULL, latest_position ASC, keyword_text ASC',
    );

    return results.map((m) => Keyword.fromMap(m)).toList();
  }

  Future<Keyword?> getKeywordById(int id) async {
    final db = await _dbManager.database;
    final results = await db.query(
      DatabaseConstants.tableKeywords,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Keyword.fromMap(results.first);
  }

  Future<Keyword?> findDuplicateKeyword({
    required int websiteId,
    required String keywordText,
    required String searchEngine,
    required String targetCountry,
    String? targetCity,
    String language = 'en',
    String device = 'Desktop',
    int? excludeId,
  }) async {
    final db = await _dbManager.database;
    final where = [
      'website_id = ?',
      'LOWER(keyword_text) = ?',
      'search_engine = ?',
      'target_country = ?',
      'language = ?',
      'device = ?',
    ];
    final args = <dynamic>[
      websiteId,
      keywordText.trim().toLowerCase(),
      searchEngine,
      targetCountry.trim().toUpperCase(),
      language.trim(),
      device.trim(),
    ];

    if (targetCity != null && targetCity.trim().isNotEmpty) {
      where.add('LOWER(target_city) = ?');
      args.add(targetCity.trim().toLowerCase());
    } else {
      where.add('(target_city IS NULL OR target_city = ?)');
      args.add('');
    }

    if (excludeId != null) {
      where.add('id != ?');
      args.add(excludeId);
    }

    final results = await db.query(
      DatabaseConstants.tableKeywords,
      where: where.join(' AND '),
      whereArgs: args,
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Keyword.fromMap(results.first);
  }

  Future<Keyword> insertKeyword(Keyword model) async {
    final db = await _dbManager.database;
    final id = await db.insert(
      DatabaseConstants.tableKeywords,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return model.copyWith(id: id);
  }

  Future<List<Keyword>> insertKeywordsBatch(List<Keyword> models) async {
    final db = await _dbManager.database;
    final List<Keyword> inserted = [];

    await db.transaction((txn) async {
      for (final model in models) {
        final id = await txn.insert(
          DatabaseConstants.tableKeywords,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id > 0) {
          inserted.add(model.copyWith(id: id));
        }
      }
    });

    return inserted;
  }

  Future<int> updateKeyword(Keyword model) async {
    final db = await _dbManager.database;
    return await db.update(
      DatabaseConstants.tableKeywords,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> toggleActiveStatus(int keywordId, bool isActive) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseConstants.tableKeywords,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [keywordId],
    );
  }

  Future<void> updateKeywordGroup(int keywordId, int? groupId) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseConstants.tableKeywords,
      {'group_id': groupId},
      where: 'id = ?',
      whereArgs: [keywordId],
    );
  }

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

  Future<int> deleteKeyword(int id) async {
    final db = await _dbManager.database;
    return await db.delete(
      DatabaseConstants.tableKeywords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> bulkDeleteKeywords(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _dbManager.database;
    return await db.delete(
      DatabaseConstants.tableKeywords,
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<RankObservation> recordObservation(RankObservation observation) async {
    final db = await _dbManager.database;
    RankObservation savedObs = observation;

    await db.transaction((txn) async {
      // 1. Fetch current keyword state
      final kwRows = await txn.query(
        DatabaseConstants.tableKeywords,
        where: 'id = ?',
        whereArgs: [observation.keywordId],
        limit: 1,
      );
      if (kwRows.isEmpty) return;
      final currentKw = Keyword.fromMap(kwRows.first);

      // 2. Fetch previous comparable observation for this keyword + searchEngine
      final prevObsRows = await txn.query(
        DatabaseConstants.tableRankObservations,
        where: 'keyword_id = ? AND search_engine = ?',
        whereArgs: [observation.keywordId, observation.searchEngine],
        orderBy: 'recorded_at DESC',
        limit: 1,
      );

      int? prevPos;
      String? prevRankingUrl;
      if (prevObsRows.isNotEmpty) {
        prevPos = prevObsRows.first['position'] as int?;
        prevRankingUrl = prevObsRows.first['ranking_url'] as String?;
      } else {
        prevPos = currentKw.positionFor(observation.searchEngine);
        prevRankingUrl = currentKw.rankingUrl;
      }

      // URL change detection
      final isUrlChange =
          prevRankingUrl != null &&
          prevRankingUrl.isNotEmpty &&
          observation.rankingUrl != null &&
          observation.rankingUrl!.isNotEmpty &&
          prevRankingUrl.toLowerCase() != observation.rankingUrl!.toLowerCase();

      // Movement calculation:
      // Positive delta means improved rank (e.g. was 10, now 4 -> 10 - 4 = +6)
      // Negative delta means dropped rank (e.g. was 4, now 10 -> 4 - 10 = -6)
      int delta = 0;
      if (prevPos != null && prevPos > 0 && observation.position > 0) {
        delta = prevPos - observation.position;
      } else if (prevPos != null && prevPos > 0 && observation.position == 0) {
        delta = -prevPos;
      } else if ((prevPos == null || prevPos == 0) &&
          observation.position > 0) {
        delta = 100 - observation.position;
      }

      // New / Lost / Recovered status transition
      String statusEvent = currentKw.statusEvent;
      DateTime? firstRankedAt = currentKw.firstRankedAt;
      DateTime? lostAt = currentKw.lostAt;

      if (observation.position > 0) {
        if (prevPos == null ||
            prevPos == 0 ||
            currentKw.firstRankedAt == null) {
          statusEvent = currentKw.lostAt != null ? 'recovered' : 'new';
          firstRankedAt ??= observation.recordedAt;
          lostAt = null;
        } else {
          statusEvent = 'normal';
        }
      } else if (observation.position == 0 && prevPos != null && prevPos > 0) {
        statusEvent = 'lost';
        lostAt = observation.recordedAt;
      }

      // Save observation to rank_observations
      final insertMap = observation.toMap();
      insertMap['previous_ranking_url'] = prevRankingUrl;
      insertMap['is_url_change'] = isUrlChange ? 1 : 0;
      final obsId = await txn.insert(
        DatabaseConstants.tableRankObservations,
        insertMap,
      );
      savedObs = observation.copyWith(
        id: obsId,
        previousRankingUrl: prevRankingUrl,
        isUrlChange: isUrlChange,
      );

      // Cannibalization detection:
      final recentUrlsRows = await txn.rawQuery(
        '''
        SELECT DISTINCT ranking_url, position, COUNT(*) as appearances
        FROM rank_observations
        WHERE keyword_id = ? AND search_engine = ? AND ranking_url IS NOT NULL AND ranking_url != ''
        GROUP BY ranking_url
        ORDER BY recorded_at DESC
        LIMIT 10;
      ''',
        [observation.keywordId, observation.searchEngine],
      );

      String cannibalizationStatus = 'none';
      if (recentUrlsRows.length > 1) {
        final urlCounts = recentUrlsRows
            .map((r) => r['appearances'] as int? ?? 1)
            .toList();
        final hasFrequentSwitching = urlCounts.every((count) => count >= 2);
        if (hasFrequentSwitching) {
          cannibalizationStatus = 'url_switching';
        } else {
          cannibalizationStatus = 'multiple_urls';
        }
      }

      // Update keyword row
      final isGoogle = observation.searchEngine.toLowerCase() != 'bing';
      final Map<String, dynamic> updateKw = {
        'ranking_url': observation.rankingUrl ?? currentKw.rankingUrl,
        'last_checked_at': observation.recordedAt.millisecondsSinceEpoch,
        'status_event': statusEvent,
        'first_ranked_at': firstRankedAt?.millisecondsSinceEpoch,
        'lost_at': lostAt?.millisecondsSinceEpoch,
        'cannibalization_status': cannibalizationStatus,
        'latest_position': observation.position,
        'previous_position': prevPos,
        'position_delta': delta,
      };

      if (isGoogle) {
        updateKw['google_position'] = observation.position;
        updateKw['google_previous_position'] = prevPos;
        updateKw['google_delta'] = delta;
      } else {
        updateKw['bing_position'] = observation.position;
        updateKw['bing_previous_position'] = prevPos;
        updateKw['bing_delta'] = delta;
      }

      await txn.update(
        DatabaseConstants.tableKeywords,
        updateKw,
        where: 'id = ?',
        whereArgs: [observation.keywordId],
      );
    });

    return savedObs;
  }

  Future<List<RankObservation>> getObservationsForKeyword(
    int keywordId, {
    String? searchEngine,
    int limit = 100,
  }) async {
    final db = await _dbManager.database;
    final where = ['keyword_id = ?'];
    final args = <dynamic>[keywordId];

    if (searchEngine != null && searchEngine.toLowerCase() != 'all') {
      where.add('search_engine = ?');
      args.add(searchEngine);
    }

    final results = await db.query(
      DatabaseConstants.tableRankObservations,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'recorded_at DESC',
      limit: limit,
    );

    return results.map((m) => RankObservation.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getCannibalizationAlerts(
    int websiteId,
  ) async {
    final db = await _dbManager.database;
    final results = await db.rawQuery(
      '''
      SELECT k.id as keyword_id, k.keyword_text, k.search_engine, k.target_country,
             k.cannibalization_status, k.ranking_url,
             COUNT(DISTINCT ro.ranking_url) as distinct_url_count,
             GROUP_CONCAT(DISTINCT ro.ranking_url) as affected_urls
      FROM keywords k
      JOIN rank_observations ro ON k.id = ro.keyword_id
      WHERE k.website_id = ? AND k.cannibalization_status != 'none'
        AND ro.ranking_url IS NOT NULL AND ro.ranking_url != ''
      GROUP BY k.id
    ''',
      [websiteId],
    );

    return results;
  }
}
