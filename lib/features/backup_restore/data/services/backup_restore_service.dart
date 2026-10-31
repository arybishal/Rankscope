import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_storage_service.dart';

/// Comprehensive Encrypted Backup & Restore Service for RankScope.
///
/// Features:
/// - Authenticated AES-256-GCM encryption with PBKDF2 (HMAC-SHA256, 100,000 iterations).
/// - Unique 16-byte cryptographic salt and 12-byte nonce per backup.
/// - Full coverage of all websites, keywords, target URLs, rankings, analytics, settings & credentials.
/// - Preview inspection before restoration.
/// - Two restoration modes: Full Restore (atomic with automatic recovery snapshot) and Merge Import.
class BackupRestoreService {
  final AppDatabase _dbManager;
  final SecureStorageService _secureStorage;

  BackupRestoreService({
    AppDatabase? dbManager,
    SecureStorageService? secureStorage,
  }) : _dbManager = dbManager ?? AppDatabase.instance,
       _secureStorage = secureStorage ?? SecureStorageService();

  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  /// Exports a complete, AES-256-GCM encrypted backup bundle to disk.
  Future<File> exportEncryptedBackup({
    required String password,
    bool includeCredentials = true,
    String? destinationDirPath,
  }) async {
    if (password.trim().isEmpty) {
      throw const ValidationException('Backup password cannot be empty.');
    }

    // 1. Checkpoint SQLite database so all WAL changes are consolidated
    await _dbManager.walCheckpoint();
    final db = await _dbManager.database;

    // 2. Query all tables
    final List<Map<String, dynamic>> websites = await db.query(
      DatabaseConstants.tableWebsites,
    );
    final List<Map<String, dynamic>> keywords = await db.query(
      DatabaseConstants.tableKeywords,
    );
    final List<Map<String, dynamic>> manualRecords = await db.query(
      DatabaseConstants.tableManualRankRecords,
    );
    final List<Map<String, dynamic>> rankObservations = await db.query(
      DatabaseConstants.tableRankObservations,
    );
    final List<Map<String, dynamic>> gscRecords = await db.query(
      DatabaseConstants.tableGscSearchAnalytics,
    );
    final List<Map<String, dynamic>> bingRecords = await db.query(
      DatabaseConstants.tableBingSearchAnalytics,
    );
    List<Map<String, dynamic>> yandexRecords = [];
    try {
      yandexRecords = await db.query(
        DatabaseConstants.tableYandexSearchAnalytics,
      );
    } catch (_) {
      // Table may not exist on pre-v5 schemas
    }
    final List<Map<String, dynamic>> compLinks = await db.query(
      DatabaseConstants.tableCompetitorKeywordLinks,
    );
    final List<Map<String, dynamic>> reportsHistory = await db.query(
      DatabaseConstants.tableReportsHistory,
    );

    // 3. Extract secure hardware credentials if explicitly enabled by user
    final Map<String, String> credentials = includeCredentials
        ? await _secureStorage.getAllCredentials()
        : {};

    // 4. Construct complete backup payload
    final now = DateTime.now();
    final Map<String, dynamic> payload = {
      'app': 'RankScope',
      'version': '2.0.0',
      'database_version': DatabaseConstants.databaseVersion,
      'exported_at': now.toIso8601String(),
      'credentials_included': includeCredentials,
      'stats': {
        'websites_count': websites.length,
        'keywords_count': keywords.length,
        'manual_records_count': manualRecords.length,
        'gsc_records_count': gscRecords.length,
        'bing_records_count': bingRecords.length,
        'yandex_records_count': yandexRecords.length,
        'integrations_count': credentials.length,
      },
      'data': {
        'websites': websites,
        'keywords': keywords,
        'manual_rank_records': manualRecords,
        'rank_observations': rankObservations,
        'gsc_search_analytics': gscRecords,
        'bing_search_analytics': bingRecords,
        'yandex_search_analytics': yandexRecords,
        'competitor_keyword_links': compLinks,
        'reports_history': reportsHistory,
        'credentials': credentials,
      },
    };

    final Uint8List plaintextBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(payload)),
    );

    // 5. Generate unique cryptographic salt & nonce
    final random = Random.secure();
    final Uint8List salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final Uint8List nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => random.nextInt(256)),
    );

    // 6. Derive key using PBKDF2
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // 7. Encrypt with AES-256-GCM
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 8. Package encrypted envelope
    final Map<String, dynamic> envelope = {
      'format': 'rankscope_encrypted_backup',
      'version': 2,
      'kdf': 'PBKDF2_HMAC_SHA256',
      'kdf_iterations': _pbkdf2Iterations,
      'cipher': 'AES_256_GCM',
      'salt_base64': base64Encode(salt),
      'nonce_base64': base64Encode(nonce),
      'mac_base64': base64Encode(secretBox.mac.bytes),
      'ciphertext_base64': base64Encode(secretBox.cipherText),
      'created_at': now.toIso8601String(),
    };

    // 9. Write to file
    final String baseDir =
        destinationDirPath ?? (await getApplicationDocumentsDirectory()).path;
    final String timestampStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final File backupFile = File(
      join(baseDir, 'RankScope_Backup_$timestampStr.rankscope'),
    );

    await backupFile.writeAsString(jsonEncode(envelope), flush: true);

    // 10. Self-verify export integrity before declaring success
    try {
      await inspectAndDecryptBackup(
        filePath: backupFile.path,
        password: password,
      );
    } catch (e) {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      throw ValidationException(
        'Export verification failed. Backup file could not be verified: $e',
      );
    }

    await AppLogger.instance.info(
      'Backup',
      'backup_exported',
      'Encrypted backup exported & verified: ${backupFile.path} (Credentials: $includeCredentials)',
    );
    return backupFile;
  }

  /// Inspects and decrypts a .rankscope backup file, verifying authentication tag and returning preview stats.
  Future<Map<String, dynamic>> inspectAndDecryptBackup({
    required String filePath,
    required String password,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const ValidationException('Backup file not found on disk.');
    }

    final String content = await file.readAsString();
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw const ValidationException(
        'Invalid backup file: not valid JSON format.',
      );
    }

    if (envelope['format'] != 'rankscope_encrypted_backup') {
      throw const ValidationException(
        'Invalid backup archive: unrecognized format.',
      );
    }

    final salt = base64Decode(envelope['salt_base64'] as String);
    final nonce = base64Decode(envelope['nonce_base64'] as String);
    final macBytes = base64Decode(envelope['mac_base64'] as String);
    final cipherText = base64Decode(envelope['ciphertext_base64'] as String);
    final iterations =
        (envelope['kdf_iterations'] as int?) ?? _pbkdf2Iterations;

    // Derive key
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // Decrypt and verify tag
    final algorithm = AesGcm.with256bits();
    List<int> decryptedBytes;
    try {
      decryptedBytes = await algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
    } on SecretBoxAuthenticationError {
      throw const ValidationException(
        'Incorrect backup password or corrupted backup file.',
      );
    } catch (e) {
      throw ValidationException('Failed to decrypt backup: $e');
    }

    final String payloadJson = utf8.decode(decryptedBytes);
    final Map<String, dynamic> payload =
        jsonDecode(payloadJson) as Map<String, dynamic>;

    if (payload['app'] != 'RankScope') {
      throw const ValidationException(
        'Invalid backup payload: not a RankScope archive.',
      );
    }

    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final websites = data['websites'] as List? ?? [];
    final keywords = data['keywords'] as List? ?? [];
    final manualRecords = data['manual_rank_records'] as List? ?? [];
    final gscRecords = data['gsc_search_analytics'] as List? ?? [];
    final bingRecords = data['bing_search_analytics'] as List? ?? [];
    final yandexRecords = data['yandex_search_analytics'] as List? ?? [];
    final credentials = data['credentials'] as Map<String, dynamic>? ?? {};

    return {
      'exported_at': payload['exported_at'] ?? envelope['created_at'],
      'version': payload['version'] ?? '1.0.0',
      'credentials_included':
          payload['credentials_included'] ?? (credentials.isNotEmpty),
      'websites_count': websites.length,
      'keywords_count': keywords.length,
      'ranking_records_count':
          manualRecords.length +
          gscRecords.length +
          bingRecords.length +
          yandexRecords.length,
      'integrations_count': credentials.length,
      'payload': payload,
    };
  }

  /// Mode A: Full Restore.
  /// Replaces current database with backup contents transactionally, creating an automatic recovery backup.
  Future<void> performFullRestore(Map<String, dynamic> payload) async {
    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ValidationException(
        'Malformed backup payload: missing data node.',
      );
    }

    // 1. Create automatic recovery backup of current database file
    await _dbManager.walCheckpoint();
    final dbPath = await getDatabasesPath();
    final liveFile = File(join(dbPath, DatabaseConstants.databaseName));
    final recoveryFile = File(
      join(dbPath, '${DatabaseConstants.databaseName}.recovery_snapshot'),
    );

    if (await liveFile.exists()) {
      await liveFile.copy(recoveryFile.path);
    }

    try {
      final db = await _dbManager.database;

      await db.transaction((txn) async {
        // Clear in reverse foreign-key dependency order
        await txn.delete(DatabaseConstants.tableCompetitorKeywordLinks);
        await txn.delete(DatabaseConstants.tableReportsHistory);
        await txn.delete(DatabaseConstants.tableGscSearchAnalytics);
        await txn.delete(DatabaseConstants.tableBingSearchAnalytics);
        try {
          await txn.delete(DatabaseConstants.tableYandexSearchAnalytics);
        } catch (_) {}
        await txn.delete(DatabaseConstants.tableRankObservations);
        await txn.delete(DatabaseConstants.tableManualRankRecords);
        await txn.delete(DatabaseConstants.tableKeywords);
        await txn.delete(DatabaseConstants.tableWebsites);

        // Repopulate websites
        final websites = (data['websites'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in websites) {
          await txn.insert(DatabaseConstants.tableWebsites, row);
        }

        // Repopulate keywords
        final keywords = (data['keywords'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in keywords) {
          await txn.insert(DatabaseConstants.tableKeywords, row);
        }

        // Repopulate manual rank records
        final manualRecords = (data['manual_rank_records'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in manualRecords) {
          await txn.insert(DatabaseConstants.tableManualRankRecords, row);
        }

        // Repopulate rank observations
        final rankObs = (data['rank_observations'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in rankObs) {
          await txn.insert(DatabaseConstants.tableRankObservations, row);
        }

        // Repopulate GSC records
        final gscRecords = (data['gsc_search_analytics'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in gscRecords) {
          await txn.insert(DatabaseConstants.tableGscSearchAnalytics, row);
        }

        // Repopulate Bing records
        final bingRecords = (data['bing_search_analytics'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in bingRecords) {
          await txn.insert(DatabaseConstants.tableBingSearchAnalytics, row);
        }

        // Repopulate Yandex records
        final yandexRecords = (data['yandex_search_analytics'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in yandexRecords) {
          try {
            await txn.insert(DatabaseConstants.tableYandexSearchAnalytics, row);
          } catch (_) {}
        }

        // Repopulate competitor keyword links
        final compLinks = (data['competitor_keyword_links'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in compLinks) {
          await txn.insert(DatabaseConstants.tableCompetitorKeywordLinks, row);
        }

        // Repopulate reports history
        final reports = (data['reports_history'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final row in reports) {
          await txn.insert(DatabaseConstants.tableReportsHistory, row);
        }
      });

      // Restore credentials
      final credentials = data['credentials'] as Map<String, dynamic>?;
      if (credentials != null && credentials.isNotEmpty) {
        await _secureStorage.restoreCredentials(credentials);
      }

      // Restore successful: remove recovery snapshot
      if (await recoveryFile.exists()) {
        await recoveryFile.delete();
      }
      await AppLogger.instance.info(
        'Backup',
        'full_restore_success',
        'Full database restore successfully completed',
      );
    } catch (e, st) {
      await AppLogger.instance.error(
        'Backup',
        'full_restore_failed',
        'Full restore failed, initiated rollback',
        error: e,
        stackTrace: st,
      );
      // Transaction aborted or error encountered: restore from recovery file if present
      await _dbManager.close();
      if (await recoveryFile.exists()) {
        await recoveryFile.copy(liveFile.path);
        await recoveryFile.delete();
      }
      await _dbManager.database;
      throw DatabaseException(
        'Full restore failed: $e. System automatically reverted to previous state.',
      );
    }
  }

  /// Mode B: Merge Import.
  /// Adds imported records without unnecessarily duplicating existing records, resolving IDs dynamically.
  Future<Map<String, int>> performMergeImport(
    Map<String, dynamic> payload,
  ) async {
    final data = payload['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ValidationException(
        'Malformed backup payload: missing data node.',
      );
    }

    final db = await _dbManager.database;
    int websitesAdded = 0;
    int keywordsAdded = 0;
    int rankRecordsAdded = 0;

    await db.transaction((txn) async {
      // 1. Merge Websites
      // Map: old backup website ID -> new/existing website ID
      final Map<int, int> websiteIdMap = {};
      final websites = (data['websites'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      for (final siteRow in websites) {
        final oldId = siteRow['id'] as int;
        final domain = siteRow['domain'] as String;
        final isCompetitor = (siteRow['is_competitor'] as int? ?? 0) == 1;

        // Check if website already exists
        final existing = await txn.query(
          DatabaseConstants.tableWebsites,
          where: 'domain = ? AND is_competitor = ?',
          whereArgs: [domain, isCompetitor ? 1 : 0],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          websiteIdMap[oldId] = existing.first['id'] as int;
        } else {
          final insertMap = Map<String, dynamic>.from(siteRow)..remove('id');
          final newId = await txn.insert(
            DatabaseConstants.tableWebsites,
            insertMap,
          );
          websiteIdMap[oldId] = newId;
          websitesAdded++;
        }
      }

      // 2. Merge Keywords
      // Map: old backup keyword ID -> new/existing keyword ID
      final Map<int, int> keywordIdMap = {};
      final keywords = (data['keywords'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      for (final kwRow in keywords) {
        final oldKwId = kwRow['id'] as int;
        final oldSiteId = kwRow['website_id'] as int;
        final mappedSiteId = websiteIdMap[oldSiteId];

        if (mappedSiteId == null) continue;

        final keywordText = kwRow['keyword_text'] as String;
        final targetCountry = kwRow['target_country'] as String? ?? 'GLOBAL';
        final targetCity = kwRow['target_city'] as String?;

        // Check if keyword exists under mapped site
        String where =
            'website_id = ? AND keyword_text = ? AND target_country = ?';
        List<dynamic> whereArgs = [mappedSiteId, keywordText, targetCountry];

        if (targetCity != null) {
          where += ' AND target_city = ?';
          whereArgs.add(targetCity);
        } else {
          where += ' AND target_city IS NULL';
        }

        final existing = await txn.query(
          DatabaseConstants.tableKeywords,
          where: where,
          whereArgs: whereArgs,
          limit: 1,
        );

        if (existing.isNotEmpty) {
          keywordIdMap[oldKwId] = existing.first['id'] as int;
        } else {
          final insertMap = Map<String, dynamic>.from(kwRow)
            ..remove('id')
            ..['website_id'] = mappedSiteId;
          final newKwId = await txn.insert(
            DatabaseConstants.tableKeywords,
            insertMap,
          );
          keywordIdMap[oldKwId] = newKwId;
          keywordsAdded++;
        }
      }

      // 3. Merge Manual Rank Records
      final manualRecords = (data['manual_rank_records'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final recordRow in manualRecords) {
        final oldKwId = recordRow['keyword_id'] as int;
        final oldSiteId = recordRow['website_id'] as int;
        final mappedKwId = keywordIdMap[oldKwId];
        final mappedSiteId = websiteIdMap[oldSiteId];

        if (mappedKwId == null || mappedSiteId == null) continue;

        final position = recordRow['position'] as int;
        final recordedAt = recordRow['recorded_at'] as int;

        // Avoid duplicate records
        final existing = await txn.query(
          DatabaseConstants.tableManualRankRecords,
          where: 'keyword_id = ? AND position = ? AND recorded_at = ?',
          whereArgs: [mappedKwId, position, recordedAt],
          limit: 1,
        );

        if (existing.isEmpty) {
          final insertMap = Map<String, dynamic>.from(recordRow)
            ..remove('id')
            ..['keyword_id'] = mappedKwId
            ..['website_id'] = mappedSiteId;
          await txn.insert(DatabaseConstants.tableManualRankRecords, insertMap);
          rankRecordsAdded++;
        }
      }

      // 3b. Merge Rank Observations
      final rankObsRecords = (data['rank_observations'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final obsRow in rankObsRecords) {
        final oldSiteId = obsRow['website_id'] as int;
        final oldKwId = obsRow['keyword_id'] as int;
        final mappedSiteId = websiteIdMap[oldSiteId];
        final mappedKwId = keywordIdMap[oldKwId];
        if (mappedSiteId == null || mappedKwId == null) continue;

        final insertMap = Map<String, dynamic>.from(obsRow)
          ..remove('id')
          ..['website_id'] = mappedSiteId
          ..['keyword_id'] = mappedKwId;
        await txn.insert(
          DatabaseConstants.tableRankObservations,
          insertMap,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 4. Merge Search Analytics (GSC & Bing)
      final gscRecords = (data['gsc_search_analytics'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final gscRow in gscRecords) {
        final oldSiteId = gscRow['website_id'] as int;
        final mappedSiteId = websiteIdMap[oldSiteId];
        if (mappedSiteId == null) continue;

        final insertMap = Map<String, dynamic>.from(gscRow)
          ..remove('id')
          ..['website_id'] = mappedSiteId;
        final id = await txn.insert(
          DatabaseConstants.tableGscSearchAnalytics,
          insertMap,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id > 0) rankRecordsAdded++;
      }

      final bingRecords = (data['bing_search_analytics'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final bingRow in bingRecords) {
        final oldSiteId = bingRow['website_id'] as int;
        final mappedSiteId = websiteIdMap[oldSiteId];
        if (mappedSiteId == null) continue;

        final insertMap = Map<String, dynamic>.from(bingRow)
          ..remove('id')
          ..['website_id'] = mappedSiteId;
        final id = await txn.insert(
          DatabaseConstants.tableBingSearchAnalytics,
          insertMap,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id > 0) rankRecordsAdded++;
      }

      // Merge Yandex Analytics
      final yandexRecords = (data['yandex_search_analytics'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final yandexRow in yandexRecords) {
        final oldSiteId = yandexRow['website_id'] as int;
        final mappedSiteId = websiteIdMap[oldSiteId];
        if (mappedSiteId == null) continue;

        final insertMap = Map<String, dynamic>.from(yandexRow)
          ..remove('id')
          ..['website_id'] = mappedSiteId;
        try {
          final id = await txn.insert(
            DatabaseConstants.tableYandexSearchAnalytics,
            insertMap,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (id > 0) rankRecordsAdded++;
        } catch (_) {}
      }
    });

    // Merge credentials if missing locally
    final credentials = data['credentials'] as Map<String, dynamic>?;
    if (credentials != null && credentials.isNotEmpty) {
      final existingCreds = await _secureStorage.getAllCredentials();
      final Map<String, dynamic> toRestore = {};
      for (final entry in credentials.entries) {
        if (!existingCreds.containsKey(entry.key) && entry.value != null) {
          toRestore[entry.key] = entry.value;
        }
      }
      if (toRestore.isNotEmpty) {
        await _secureStorage.restoreCredentials(toRestore);
      }
    }

    await AppLogger.instance.info(
      'Backup',
      'merge_import_success',
      'Merge import completed: added $websitesAdded websites, $keywordsAdded keywords, $rankRecordsAdded ranking records',
    );

    return {
      'websites_added': websitesAdded,
      'keywords_added': keywordsAdded,
      'rankings_added': rankRecordsAdded,
    };
  }
}
