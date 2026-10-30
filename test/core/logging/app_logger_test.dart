import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/logging/app_logger.dart';
import 'package:rankscope/core/logging/log_level.dart';
import 'package:rankscope/core/logging/log_sanitizer.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('LogSanitizer Redaction Tests', () {
    test('redacts Authorization Bearer tokens', () {
      const raw = 'Request header Authorization: Bearer ya29.a0AfH6SMDh1234567890abcdef and token 1//04xyz12345678901234567890';
      final sanitized = LogSanitizer.sanitize(raw);
      expect(sanitized.contains('ya29.a0AfH6SMDh1234567890abcdef'), false);
      expect(sanitized.contains('1//04xyz12345678901234567890'), false);
      expect(sanitized.contains('[REDACTED]'), true);
    });

    test('redacts passwords and api keys', () {
      const raw = 'Saving credentials: password="SuperSecretPassword!", api_key="abcdef123456abcdef123456abcdef12"';
      final sanitized = LogSanitizer.sanitize(raw);
      expect(sanitized.contains('SuperSecretPassword!'), false);
      expect(sanitized.contains('abcdef123456abcdef123456abcdef12'), false);
      expect(sanitized.contains('[REDACTED]'), true);
    });
  });

  group('AppLogger Database Integration Tests', () {
    test('logs entries, queries with filters, computes stats, and exports', () async {
      await AppDatabase.instance.initCustom(inMemoryDatabasePath);
      final logger = AppLogger.instance;

      await logger.debug('Database', 'db_init', 'Database connection established');
      await logger.info('Websites', 'site_added', 'Added domain example.com');
      await logger.warning('GSC', 'rate_limit', 'Approaching quota limit: 90% reached');
      await logger.error(
        'Backup',
        'export_failed',
        'Disk full error occurred',
        error: 'No space left on device',
      );
      await logger.critical(
        'Security',
        'auth_tamper',
        'Checksum mismatch on key with password="hacked"',
      );

      // Check stats
      final stats = await logger.getLogStats();
      expect(stats['total'], 5);
      expect(stats['errors'], 2); // ERROR + CRITICAL
      expect(stats['warnings'], 1);

      // Verify sanitization in stored log
      final securityLogs = await logger.getLogs(module: 'Security');
      expect(securityLogs.length, 1);
      expect(securityLogs.first.message.contains('hacked'), false);
      expect(securityLogs.first.message.contains('[REDACTED]'), true);

      // Query by level
      final warnLogs = await logger.getLogs(level: LogLevel.warning);
      expect(warnLogs.length, 1);
      expect(warnLogs.first.eventName, 'rate_limit');

      // Query by search keyword
      final searchResults = await logger.getLogs(searchQuery: 'example.com');
      expect(searchResults.length, 1);
      expect(searchResults.first.module, 'Websites');

      // Export as text
      final textExport = await logger.exportAsTextString();
      expect(textExport.contains('RankScope Diagnostic Logs Export'), true);
      expect(textExport.contains('example.com'), true);

      // Export as JSON
      final jsonExport = await logger.exportAsJsonString();
      final parsed = jsonDecode(jsonExport) as Map<String, dynamic>;
      expect(parsed['count'], 5);

      // Clear logs
      await logger.clearLogs();
      final clearedStats = await logger.getLogStats();
      expect(clearedStats['total'], 0);
    });
  });
}
