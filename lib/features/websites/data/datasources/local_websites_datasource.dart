import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/website.dart';

/// Direct SQLite data source for website entities.
class LocalWebsitesDatasource {
  final AppDatabase _dbManager;

  LocalWebsitesDatasource({AppDatabase? dbManager})
    : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<Website>> getWebsites({bool? isCompetitor}) async {
    final db = await _dbManager.database;
    String? where;
    List<dynamic>? whereArgs;

    if (isCompetitor != null) {
      where = 'is_competitor = ?';
      whereArgs = [isCompetitor ? 1 : 0];
    }

    final List<Map<String, dynamic>> results = await db.query(
      DatabaseConstants.tableWebsites,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );

    return results.map((m) => Website.fromMap(m)).toList();
  }

  Future<Website?> getWebsiteById(int id) async {
    final db = await _dbManager.database;
    final List<Map<String, dynamic>> results = await db.query(
      DatabaseConstants.tableWebsites,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Website.fromMap(results.first);
  }

  Future<Website?> getWebsiteByDomain(
    String domain, {
    required bool isCompetitor,
  }) async {
    final db = await _dbManager.database;
    final List<Map<String, dynamic>> results = await db.query(
      DatabaseConstants.tableWebsites,
      where: 'domain = ? AND is_competitor = ?',
      whereArgs: [domain, isCompetitor ? 1 : 0],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Website.fromMap(results.first);
  }

  Future<Website> insertWebsite(Website model) async {
    final db = await _dbManager.database;
    final id = await db.insert(
      DatabaseConstants.tableWebsites,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return model.copyWith(id: id);
  }

  Future<int> updateWebsite(Website model) async {
    final db = await _dbManager.database;
    return await db.update(
      DatabaseConstants.tableWebsites,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<int> deleteWebsite(int id) async {
    final db = await _dbManager.database;
    return await db.delete(
      DatabaseConstants.tableWebsites,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
