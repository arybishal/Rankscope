import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/features/keywords/data/services/search_performance_sync_service.dart';
import 'package:rankscope/features/sync/data/datasources/sync_history_datasource.dart';
import 'package:rankscope/features/sync/data/services/sync_all_service.dart';
import 'package:rankscope/features/websites/data/datasources/local_websites_datasource.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';

import '../../test_helper.dart';

class FakeSearchPerformanceSyncService extends SearchPerformanceSyncService {
  final bool googleConfig;
  final bool bingConfig;
  final bool yandexConfig;
  final bool throwGoogleError;
  final bool throwSiteError;
  int syncCallCount = 0;

  FakeSearchPerformanceSyncService({
    this.googleConfig = true,
    this.bingConfig = true,
    this.yandexConfig = false,
    this.throwGoogleError = false,
    this.throwSiteError = false,
  });

  @override
  Future<bool> isGoogleConfigured() async => googleConfig;

  @override
  Future<bool> isBingConfigured() async => bingConfig;

  @override
  Future<bool> isYandexConfigured() async => yandexConfig;

  @override
  Future<SearchSyncResult> syncPerformanceForWebsite({
    required int websiteId,
    required String domain,
    String? gscPropertyId,
    String? bingSiteUrl,
    String? yandexHostId,
    String? country,
    String? device,
    String? searchType,
    int? dateWindowDays,
  }) async {
    syncCallCount++;

    if (throwSiteError && domain == 'failing.com') {
      throw Exception('Simulated fatal connection reset');
    }

    return SearchSyncResult(
      totalKeywords: 10,
      matchedKeywords: 7,
      googleQueriesAvailable: throwGoogleError ? 0 : 50,
      bingQueriesAvailable: 25,
      yandexQueriesAvailable: 0,
      googleConnected: googleConfig,
      bingConnected: bingConfig,
      yandexConnected: yandexConfig,
      googleStatusMessage: throwGoogleError ? 'Google sync failed: 401' : 'Synced 50 GSC queries',
      bingStatusMessage: 'Synced 25 Bing queries',
      yandexStatusMessage: 'Yandex Webmaster not connected',
    );
  }
}

class FakeWebsitesDatasource extends LocalWebsitesDatasource {
  final List<Website> testSites;

  FakeWebsitesDatasource(this.testSites);

  @override
  Future<List<Website>> getWebsites({bool? isCompetitor}) async {
    if (isCompetitor != null) {
      return testSites.where((s) => s.isCompetitor == isCompetitor).toList();
    }
    return testSites;
  }
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  group('SyncAllService Orchestration & Reliability Tests', () {
    late AppDatabase dbManager;
    late SyncHistoryDatasource historyDatasource;
    late SecureStorageService secureStorage;

    setUp(() async {
      dbManager = AppDatabase.instance;
      await dbManager.initCustom(inMemoryDatabasePath);
      historyDatasource = SyncHistoryDatasource(dbManager: dbManager);
      setupMockSecureStorage();
      secureStorage = SecureStorageService();
    });

    tearDown(() async {
      await dbManager.close();
    });

    test('Syncs all active websites and skips competitor domains', () async {
      final now = DateTime.now();
      final sites = [
        Website(id: 1, domain: 'primary1.com', label: 'Primary 1', isCompetitor: false, createdAt: now, updatedAt: now),
        Website(id: 2, domain: 'primary2.com', label: 'Primary 2', isCompetitor: false, createdAt: now, updatedAt: now),
        Website(id: 3, domain: 'competitor.com', label: 'Competitor', isCompetitor: true, createdAt: now, updatedAt: now),
      ];

      final fakeDatasource = FakeWebsitesDatasource(sites);
      final fakeSyncService = FakeSearchPerformanceSyncService();

      final service = SyncAllService(
        websitesDatasource: fakeDatasource,
        searchSyncService: fakeSyncService,
        secureStorage: secureStorage,
        historyDatasource: historyDatasource,
      );

      final summary = await service.syncAllWebsites();

      expect(summary.totalWebsites, 2); // only non-competitors
      expect(summary.successfulWebsites, 2);
      expect(summary.failedWebsites, 0);
      expect(summary.isSuccess, isTrue);
      expect(fakeSyncService.syncCallCount, 2);

      // Verify audit history saved in SQLite
      final history = await historyDatasource.getRecentRecords();
      expect(history.length, 4); // 2 websites * 2 connected engines (Google & Bing)
    });

    test('Isolated failure in one website does not stop other websites', () async {
      final now = DateTime.now();
      final sites = [
        Website(id: 1, domain: 'good1.com', label: 'Good 1', isCompetitor: false, createdAt: now, updatedAt: now),
        Website(id: 2, domain: 'failing.com', label: 'Failing', isCompetitor: false, createdAt: now, updatedAt: now),
        Website(id: 3, domain: 'good2.com', label: 'Good 2', isCompetitor: false, createdAt: now, updatedAt: now),
      ];

      final fakeDatasource = FakeWebsitesDatasource(sites);
      final fakeSyncService = FakeSearchPerformanceSyncService(throwSiteError: true);

      final service = SyncAllService(
        websitesDatasource: fakeDatasource,
        searchSyncService: fakeSyncService,
        secureStorage: secureStorage,
        historyDatasource: historyDatasource,
      );

      final summary = await service.syncAllWebsites();

      expect(summary.totalWebsites, 3);
      expect(summary.successfulWebsites, 2);
      expect(summary.failedWebsites, 1);
      expect(summary.status, 'partial_success');
      expect(summary.websiteDetails[1].isSuccess, isFalse);
      expect(summary.websiteDetails[1].errorMessage, contains('Simulated fatal connection reset'));
      expect(summary.websiteDetails[2].isSuccess, isTrue); // continued execution
    });

    test('Prevents overlapping or duplicate syncs via concurrency lock', () async {
      final now = DateTime.now();
      final sites = [
        Website(id: 1, domain: 'slow.com', label: 'Slow', isCompetitor: false, createdAt: now, updatedAt: now),
      ];

      final fakeDatasource = FakeWebsitesDatasource(sites);
      final fakeSyncService = FakeSearchPerformanceSyncService();

      final service = SyncAllService(
        websitesDatasource: fakeDatasource,
        searchSyncService: fakeSyncService,
        secureStorage: secureStorage,
        historyDatasource: historyDatasource,
      );

      // Start first sync
      final future1 = service.syncAllWebsites();

      // Immediately attempt second sync while first is running
      expect(
        () => service.syncAllWebsites(),
        throwsA(isA<SyncInProgressException>()),
      );

      await future1;
      expect(service.isSyncing, isFalse);
    });

    test('Progress notifier emits updates per website', () async {
      final now = DateTime.now();
      final sites = [
        Website(id: 1, domain: 'step1.com', label: 'Step 1', isCompetitor: false, createdAt: now, updatedAt: now),
        Website(id: 2, domain: 'step2.com', label: 'Step 2', isCompetitor: false, createdAt: now, updatedAt: now),
      ];

      final fakeDatasource = FakeWebsitesDatasource(sites);
      final fakeSyncService = FakeSearchPerformanceSyncService();

      final service = SyncAllService(
        websitesDatasource: fakeDatasource,
        searchSyncService: fakeSyncService,
        secureStorage: secureStorage,
        historyDatasource: historyDatasource,
      );

      final List<String> progressOps = [];
      await service.syncAllWebsites(
        onProgress: (p) => progressOps.add(p.currentOperation),
      );

      expect(progressOps.length, greaterThanOrEqualTo(2));
      expect(progressOps.any((op) => op.contains('step1.com')), isTrue);
      expect(progressOps.any((op) => op.contains('step2.com')), isTrue);
      expect(progressOps.last, 'Completed');
    });
  });
}
