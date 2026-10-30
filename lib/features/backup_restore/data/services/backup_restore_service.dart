import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/checksum_util.dart';

/// Air-gapped backup and atomic restore service for RankScope local database.
class BackupRestoreService {
  final AppDatabase _dbManager;

  BackupRestoreService({AppDatabase? dbManager})
      : _dbManager = dbManager ?? AppDatabase.instance;

  /// Creates a self-contained backup bundle with SHA-256 integrity checksum.
  Future<Map<String, dynamic>> createBackupBundle() async {
    // 1. Flush SQLite write-ahead log to main database file
    await _dbManager.walCheckpoint();

    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, DatabaseConstants.databaseName));

    if (!await dbFile.exists()) {
      throw const DatabaseException('Database file not found on disk for backup.');
    }

    final Uint8List dbBytes = await dbFile.readAsBytes();
    final String checksum = ChecksumUtil.calculateSha256(dbBytes);
    final String base64Payload = base64Encode(dbBytes);

    return {
      'app': 'RankScope',
      'version': '1.0.0',
      'database_version': DatabaseConstants.databaseVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'checksum_sha256': checksum,
      'payload_bytes_base64': base64Payload,
    };
  }

  /// Restores database bundle with SHA-256 verification and automatic rollback on failure.
  Future<bool> restoreFromBundle(Map<String, dynamic> bundle) async {
    // 1. Header validation
    if (bundle['app'] != 'RankScope') {
      throw const ValidationException('Invalid backup file: not a RankScope archive.');
    }

    final dbVersion = bundle['database_version'] as int? ?? 1;
    if (dbVersion > DatabaseConstants.databaseVersion) {
      throw ValidationException(
        'Incompatible backup schema: version $dbVersion is higher than app version ${DatabaseConstants.databaseVersion}. Update the app first.',
      );
    }

    final expectedChecksum = bundle['checksum_sha256'] as String?;
    final base64Payload = bundle['payload_bytes_base64'] as String?;

    if (expectedChecksum == null || base64Payload == null) {
      throw const ValidationException('Corrupted backup bundle: missing checksum or payload.');
    }

    // 2. Decode and verify integrity
    final Uint8List restoredBytes = base64Decode(base64Payload);
    final isValid = ChecksumUtil.verifyChecksum(restoredBytes, expectedChecksum);

    if (!isValid) {
      throw const ValidationException('Checksum verification failed: archive data may be corrupted or tampered with.');
    }

    // 3. Prepare rollback copy
    final dbPath = await getDatabasesPath();
    final liveFile = File(join(dbPath, DatabaseConstants.databaseName));
    final rollbackFile = File(join(dbPath, '${DatabaseConstants.databaseName}.rollback'));

    await _dbManager.close();

    if (await liveFile.exists()) {
      await liveFile.copy(rollbackFile.path);
    }

    // 4. Overwrite live database with restored bytes
    try {
      await liveFile.writeAsBytes(restoredBytes, flush: true);

      // Re-open and verify integrity check
      final isHealthy = await _dbManager.runIntegrityCheck();
      if (!isHealthy) {
        throw const DatabaseException('Integrity check failed on restored database.');
      }

      // Success: delete rollback file
      if (await rollbackFile.exists()) {
        await rollbackFile.delete();
      }
      return true;
    } catch (e) {
      // Automatic Rollback!
      if (await rollbackFile.exists()) {
        await rollbackFile.copy(liveFile.path);
        await rollbackFile.delete();
      }
      // Re-open original database
      await _dbManager.database;
      throw DatabaseException('Failed to restore database: $e. System automatically rolled back to previous state.');
    }
  }
}
