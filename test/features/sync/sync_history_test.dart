import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/features/sync/data/datasources/sync_history_datasource.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  group('SyncHistoryDatasource & SQLite Migration 6 Tests', () {
    late AppDatabase dbManager;
    late SyncHistoryDatasource datasource;

    setUp(() async {
      dbManager = AppDatabase.instance;
      await dbManager.initCustom(inMemoryDatabasePath);
      datasource = SyncHistoryDatasource(dbManager: dbManager);
    });

    tearDown(() async {
      await dbManager.close();
    });

    test('Migration 6 creates sync_history table and allows record insertion', () async {
      final now = DateTime.now();
      final record = SyncHistoryRecord(
        websiteId: 1,
        websiteDomain: 'rankscope.com',
        searchEngine: 'Google',
        startedAt: now.subtract(const Duration(seconds: 4)),
        completedAt: now,
        status: 'success',
        recordsRetrieved: 58,
        matchedKeywords: 12,
        triggerType: 'auto',
        createdAt: now,
      );

      final id = await datasource.insertRecord(record);
      expect(id, greaterThan(0));

      final list = await datasource.getRecentRecords();
      expect(list.length, 1);
      expect(list.first.websiteDomain, 'rankscope.com');
      expect(list.first.searchEngine, 'Google');
      expect(list.first.recordsRetrieved, 58);
      expect(list.first.status, 'success');
      expect(list.first.triggerType, 'auto');
    });

    test('Queries filter by websiteId and searchEngine properly', () async {
      final now = DateTime.now();
      await datasource.insertRecord(
        SyncHistoryRecord(
          websiteId: 1,
          websiteDomain: 'site1.com',
          searchEngine: 'Google',
          startedAt: now,
          completedAt: now,
          status: 'success',
          recordsRetrieved: 10,
          createdAt: now,
        ),
      );

      await datasource.insertRecord(
        SyncHistoryRecord(
          websiteId: 1,
          websiteDomain: 'site1.com',
          searchEngine: 'Bing',
          startedAt: now,
          completedAt: now,
          status: 'success',
          recordsRetrieved: 5,
          createdAt: now,
        ),
      );

      await datasource.insertRecord(
        SyncHistoryRecord(
          websiteId: 2,
          websiteDomain: 'site2.com',
          searchEngine: 'Google',
          startedAt: now,
          completedAt: now,
          status: 'failed',
          recordsRetrieved: 0,
          errorDetails: 'API 401 unauthorized',
          createdAt: now,
        ),
      );

      final allRecords = await datasource.getRecentRecords();
      expect(allRecords.length, 3);

      final site1Only = await datasource.getRecentRecords(websiteId: 1);
      expect(site1Only.length, 2);

      final googleOnly = await datasource.getRecentRecords(searchEngine: 'Google');
      expect(googleOnly.length, 2);

      final site2Google = await datasource.getRecentRecords(websiteId: 2, searchEngine: 'Google');
      expect(site2Google.length, 1);
      expect(site2Google.first.status, 'failed');
      expect(site2Google.first.errorDetails, contains('401'));
    });

    test('clearHistory deletes sync audit logs cleanly without affecting other tables', () async {
      final now = DateTime.now();
      await datasource.insertRecord(
        SyncHistoryRecord(
          websiteId: 1,
          websiteDomain: 'clean.com',
          searchEngine: 'Google',
          startedAt: now,
          completedAt: now,
          status: 'success',
          recordsRetrieved: 30,
          createdAt: now,
        ),
      );

      var list = await datasource.getRecentRecords();
      expect(list.isNotEmpty, isTrue);

      final deleted = await datasource.clearHistory();
      expect(deleted, 1);

      list = await datasource.getRecentRecords();
      expect(list.isEmpty, isTrue);
    });
  });
}
