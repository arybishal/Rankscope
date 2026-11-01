import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/sync/domain/models/sync_models.dart';

void main() {
  group('Sync Models Serialization and Aggregates', () {
    test('EngineSyncDetail converts to and from map accurately', () {
      const detail = EngineSyncDetail(
        engine: 'Google',
        isConnected: true,
        isSuccess: true,
        queriesCount: 42,
        message: 'Synced 42 GSC queries',
      );

      final map = detail.toMap();
      final reconstructed = EngineSyncDetail.fromMap(map);

      expect(reconstructed.engine, 'Google');
      expect(reconstructed.isConnected, isTrue);
      expect(reconstructed.isSuccess, isTrue);
      expect(reconstructed.queriesCount, 42);
      expect(reconstructed.message, 'Synced 42 GSC queries');
    });

    test('WebsiteSyncDetail aggregates engine metrics accurately', () {
      const detail = WebsiteSyncDetail(
        websiteId: 1,
        domain: 'example.com',
        label: 'Example Site',
        isSuccess: true,
        totalKeywords: 20,
        matchedKeywords: 15,
        engineDetails: [
          EngineSyncDetail(
            engine: 'Google',
            isConnected: true,
            isSuccess: true,
            queriesCount: 100,
          ),
          EngineSyncDetail(
            engine: 'Bing',
            isConnected: true,
            isSuccess: true,
            queriesCount: 50,
          ),
          EngineSyncDetail(
            engine: 'Yandex',
            isConnected: false,
            isSuccess: false,
            queriesCount: 0,
          ),
        ],
      );

      expect(detail.getEngine('Google')?.queriesCount, 100);
      expect(detail.getEngine('Bing')?.queriesCount, 50);
      expect(detail.getEngine('Yandex')?.isConnected, isFalse);
      expect(detail.getEngine('NonExistent'), isNull);

      final map = detail.toMap();
      final parsed = WebsiteSyncDetail.fromMap(map);
      expect(parsed.domain, 'example.com');
      expect(parsed.engineDetails.length, 3);
    });

    test('SyncSummary calculates overall totals and handles json serialization', () {
      final now = DateTime.now();
      final summary = SyncSummary(
        startedAt: now.subtract(const Duration(seconds: 10)),
        completedAt: now,
        status: 'success',
        totalWebsites: 2,
        successfulWebsites: 2,
        failedWebsites: 0,
        totalQueriesSynced: 210,
        isBackground: true,
        overallMessage: 'Sync All finished successfully',
        websiteDetails: const [
          WebsiteSyncDetail(
            websiteId: 1,
            domain: 'alpha.com',
            label: 'Alpha',
            isSuccess: true,
            totalKeywords: 10,
            matchedKeywords: 8,
            engineDetails: [
              EngineSyncDetail(engine: 'Google', isConnected: true, isSuccess: true, queriesCount: 100),
              EngineSyncDetail(engine: 'Bing', isConnected: true, isSuccess: true, queriesCount: 40),
            ],
          ),
          WebsiteSyncDetail(
            websiteId: 2,
            domain: 'beta.com',
            label: 'Beta',
            isSuccess: true,
            totalKeywords: 8,
            matchedKeywords: 5,
            engineDetails: [
              EngineSyncDetail(engine: 'Google', isConnected: true, isSuccess: true, queriesCount: 50),
              EngineSyncDetail(engine: 'Yandex', isConnected: true, isSuccess: true, queriesCount: 20),
            ],
          ),
        ],
      );

      expect(summary.isSuccess, isTrue);
      expect(summary.hasFailures, isFalse);
      expect(summary.googleQueries, 150);
      expect(summary.bingQueries, 40);
      expect(summary.yandexQueries, 20);
      expect(summary.totalMatchedKeywords, 13);

      final jsonStr = summary.toJson();
      final reconstructed = SyncSummary.fromJson(jsonStr);

      expect(reconstructed.totalWebsites, 2);
      expect(reconstructed.totalQueriesSynced, 210);
      expect(reconstructed.googleQueries, 150);
      expect(reconstructed.isBackground, isTrue);
    });
  });
}
