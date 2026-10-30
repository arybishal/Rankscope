import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/database_constants.dart';
import 'database_migrations.dart';

/// Singleton manager for RankScope embedded SQLite database.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _database;

  /// Returns the active SQLite database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase({String? customPath}) async {
    final String dbPath = customPath ?? await getDatabasesPath();
    final String path = join(dbPath, DatabaseConstants.databaseName);

    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Initialize database for unit testing with custom or in-memory path.
  Future<Database> initCustom(String path) async {
    await close();
    _database = await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
    await db.execute('PRAGMA synchronous = NORMAL;');
    await db.execute('PRAGMA busy_timeout = 5000;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await DatabaseMigrations.applyMigrations(db, 0, version);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DatabaseMigrations.applyMigrations(db, oldVersion, newVersion);
  }

  /// Flushes write-ahead log to disk for safe backup snapshotting.
  Future<void> walCheckpoint() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
  }

  /// Performs database integrity check. Returns true if healthy.
  Future<bool> runIntegrityCheck() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA integrity_check;');
    if (result.isNotEmpty && result.first.values.isNotEmpty) {
      return result.first.values.first == 'ok';
    }
    return false;
  }

  /// Closes database connection pool.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
