import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../models/keyword_model.dart';

/// Direct SQLite data source for keyword records.
class LocalKeywordsDatasource {
  final AppDatabase _dbManager;

  LocalKeywordsDatasource({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<KeywordModel>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? tag,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = ['website_id = ?'];
    final List<dynamic> whereArgs = [websiteId];

    if (isActive != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(isActive ? 1 : 0);
    }

    if (tag != null && tag.isNotEmpty) {
      whereClauses.add('tags LIKE ?');
      whereArgs.add('%$tag%');
    }

    final results = await db.query(
      DatabaseConstants.tableKeywords,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'latest_position IS NULL, latest_position ASC, keyword_text ASC',
    );

    return results.map((m) => KeywordModel.fromMap(m)).toList();
  }

  Future<KeywordModel?> getKeywordById(int id) async {
    final db = await _dbManager.database;
    final results = await db.query(
      DatabaseConstants.tableKeywords,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return KeywordModel.fromMap(results.first);
  }

  Future<KeywordModel> insertKeyword(KeywordModel model) async {
    final db = await _dbManager.database;
    final id = await db.insert(
      DatabaseConstants.tableKeywords,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return model.copyWith(id: id) as KeywordModel;
  }

  Future<List<KeywordModel>> insertKeywordsBatch(List<KeywordModel> models) async {
    final db = await _dbManager.database;
    final List<KeywordModel> inserted = [];

    await db.transaction((txn) async {
      for (final model in models) {
        final id = await txn.insert(
          DatabaseConstants.tableKeywords,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id > 0) {
          inserted.add(model.copyWith(id: id) as KeywordModel);
        }
      }
    });

    return inserted;
  }

  Future<int> updateKeyword(KeywordModel model) async {
    final db = await _dbManager.database;
    return await db.update(
      DatabaseConstants.tableKeywords,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> updateKeywordPosition(int keywordId, int newPosition) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      final current = await txn.query(
        DatabaseConstants.tableKeywords,
        columns: ['latest_position'],
        where: 'id = ?',
        whereArgs: [keywordId],
      );

      int? oldPos;
      if (current.isNotEmpty && current.first['latest_position'] != null) {
        oldPos = current.first['latest_position'] as int?;
      }

      // Delta: positive means improved rank (e.g. was 10, now 4 -> 10 - 4 = +6)
      final int delta = oldPos != null ? (oldPos - newPosition) : 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await txn.update(
        DatabaseConstants.tableKeywords,
        {
          'previous_position': oldPos,
          'latest_position': newPosition,
          'position_delta': delta,
          'last_checked_at': nowMs,
        },
        where: 'id = ?',
        whereArgs: [keywordId],
      );
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
}
