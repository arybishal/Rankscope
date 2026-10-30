import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/database_constants.dart';
import '../database/app_database.dart';
import 'log_entry.dart';
import 'log_level.dart';
import 'log_sanitizer.dart';

/// Centralized diagnostic logging service for RankScope.
///
/// Features:
/// - Asynchronous, non-blocking SQLite persistence with structured metadata.
/// - Automatic credential and token redaction (LogSanitizer).
/// - Configurable retention limit (default: 2,000 entries) preventing storage growth.
/// - Full querying, filtering, statistical rollups, and .txt / .json export.
class AppLogger {
  AppLogger._internal();
  static final AppLogger instance = AppLogger._internal();

  final AppDatabase _dbManager = AppDatabase.instance;
  static const int maxRetentionCount = 2000;
  int _writeCounter = 0;

  // --- Convenience Logging Methods ---

  Future<void> debug(String module, String eventName, String message, {String? details}) async {
    await log(LogLevel.debug, module, eventName, message, details: details);
  }

  Future<void> info(String module, String eventName, String message, {String? details}) async {
    await log(LogLevel.info, module, eventName, message, details: details);
  }

  Future<void> warning(String module, String eventName, String message, {String? details}) async {
    await log(LogLevel.warning, module, eventName, message, details: details);
  }

  Future<void> error(
    String module,
    String eventName,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    final buffer = StringBuffer();
    if (error != null) buffer.writeln('Error: $error');
    if (stackTrace != null) buffer.writeln('StackTrace:\n$stackTrace');
    await log(
      LogLevel.error,
      module,
      eventName,
      message,
      details: buffer.isNotEmpty ? buffer.toString() : null,
    );
  }

  Future<void> critical(
    String module,
    String eventName,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    final buffer = StringBuffer();
    if (error != null) buffer.writeln('Critical Error: $error');
    if (stackTrace != null) buffer.writeln('StackTrace:\n$stackTrace');
    await log(
      LogLevel.critical,
      module,
      eventName,
      message,
      details: buffer.isNotEmpty ? buffer.toString() : null,
    );
  }

  /// Core write method with automatic data sanitization and bounded retention.
  Future<void> log(
    LogLevel level,
    String module,
    String eventName,
    String message, {
    String? details,
  }) async {
    try {
      final sanitizedMessage = LogSanitizer.sanitize(message);
      final sanitizedDetails = details != null ? LogSanitizer.sanitize(details) : null;
      final now = DateTime.now();

      final entry = LogEntry(
        timestamp: now,
        level: level,
        module: module,
        eventName: eventName,
        message: sanitizedMessage,
        details: sanitizedDetails,
      );

      final db = await _dbManager.database;
      await db.insert(
        DatabaseConstants.tableAppLogs,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _writeCounter++;
      // Every 50 log writes, enforce retention limit to keep overhead near-zero
      if (_writeCounter % 50 == 0) {
        await pruneOldLogs();
      }
    } catch (_) {
      // Logging should never throw unhandled exceptions or crash application flows
    }
  }

  /// Removes log entries beyond the maximum retention limit.
  Future<void> pruneOldLogs() async {
    try {
      final db = await _dbManager.database;
      await db.rawDelete('''
        DELETE FROM ${DatabaseConstants.tableAppLogs}
        WHERE id NOT IN (
          SELECT id FROM ${DatabaseConstants.tableAppLogs}
          ORDER BY timestamp DESC
          LIMIT $maxRetentionCount
        );
      ''');
    } catch (_) {}
  }

  /// Queries logs with optional filtering by severity, module, search keyword, and date.
  Future<List<LogEntry>> getLogs({
    LogLevel? level,
    String? module,
    String? searchQuery,
    DateTime? fromDate,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _dbManager.database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (level != null) {
      whereClauses.add('level = ?');
      whereArgs.add(level.label);
    }

    if (module != null && module.isNotEmpty && module != 'ALL') {
      whereClauses.add('module = ?');
      whereArgs.add(module);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(message LIKE ? OR event_name LIKE ? OR module LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    if (fromDate != null) {
      whereClauses.add('timestamp >= ?');
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }

    final results = await db.query(
      DatabaseConstants.tableAppLogs,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((m) => LogEntry.fromMap(m)).toList();
  }

  /// Computes summary metrics for logs dashboard.
  Future<Map<String, dynamic>> getLogStats() async {
    final db = await _dbManager.database;

    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseConstants.tableAppLogs};');
    final int total = Sqflite.firstIntValue(totalResult) ?? 0;

    final errorResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${DatabaseConstants.tableAppLogs} WHERE level IN ('ERROR', 'CRITICAL');",
    );
    final int errors = Sqflite.firstIntValue(errorResult) ?? 0;

    final warnResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${DatabaseConstants.tableAppLogs} WHERE level = 'WARNING';",
    );
    final int warnings = Sqflite.firstIntValue(warnResult) ?? 0;

    final latestResult = await db.query(
      DatabaseConstants.tableAppLogs,
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    LogEntry? latest;
    if (latestResult.isNotEmpty) {
      latest = LogEntry.fromMap(latestResult.first);
    }

    return {
      'total': total,
      'errors': errors,
      'warnings': warnings,
      'latest': latest,
    };
  }

  /// Clears all recorded log entries.
  Future<void> clearLogs() async {
    final db = await _dbManager.database;
    await db.delete(DatabaseConstants.tableAppLogs);
  }

  /// Exports logs as human-readable .txt formatted string.
  Future<String> exportAsTextString([List<LogEntry>? specificLogs]) async {
    final logs = specificLogs ?? await getLogs(limit: maxRetentionCount);
    final buffer = StringBuffer();
    buffer.writeln('=== RankScope Diagnostic Logs Export ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Entries: ${logs.length}');
    buffer.writeln('========================================\n');

    for (final log in logs) {
      buffer.writeln(log.toFormattedString());
      buffer.writeln('----------------------------------------');
    }

    return buffer.toString();
  }

  /// Exports logs as structured JSON string.
  Future<String> exportAsJsonString([List<LogEntry>? specificLogs]) async {
    final logs = specificLogs ?? await getLogs(limit: maxRetentionCount);
    final list = logs.map((l) => l.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'RankScope',
      'exported_at': DateTime.now().toIso8601String(),
      'count': list.length,
      'logs': list,
    });
  }

  /// Creates physical .txt file with name `RankScope_Logs_YYYY-MM-DD_HH-mm.txt`.
  Future<File> exportToTextFile({String? destinationDir}) async {
    final text = await exportAsTextString();
    final now = DateTime.now();
    final timestampStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final dir = destinationDir ?? (await getApplicationDocumentsDirectory()).path;
    final file = File(join(dir, 'RankScope_Logs_$timestampStr.txt'));
    await file.writeAsString(text, flush: true);
    return file;
  }

  /// Creates physical .json file with name `RankScope_Logs_YYYY-MM-DD_HH-mm.json`.
  Future<File> exportToJsonFile({String? destinationDir}) async {
    final jsonText = await exportAsJsonString();
    final now = DateTime.now();
    final timestampStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final dir = destinationDir ?? (await getApplicationDocumentsDirectory()).path;
    final file = File(join(dir, 'RankScope_Logs_$timestampStr.json'));
    await file.writeAsString(jsonText, flush: true);
    return file;
  }
}
