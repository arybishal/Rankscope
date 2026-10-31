import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/constants/database_constants.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/utils/url_validator.dart';
import 'package:rankscope/features/dashboard/presentation/controllers/dashboard_trend_controller.dart';
import 'package:rankscope/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keywords_datasource.dart';
import 'package:rankscope/features/keywords/data/repositories/keywords_repository_impl.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
    setupMockSecureStorage();
  });

  group('Target URL Canonical Matching Tests', () {
    test('Identical URLs match perfectly', () {
      expect(
        UrlValidator.urlsMatch(
          'https://bestfreepdftools.com/pdf/pdf-editor/',
          'https://bestfreepdftools.com/pdf/pdf-editor/',
        ),
        isTrue,
      );
    });

    test('Normalizes protocol, www, and trailing slash differences', () {
      expect(
        UrlValidator.urlsMatch(
          'https://bestfreepdftools.com/pdf/pdf-editor/',
          'http://www.bestfreepdftools.com/pdf/pdf-editor',
        ),
        isTrue,
      );
    });

    test(
      'Correctly identifies different pages receiving search visibility',
      () {
        expect(
          UrlValidator.urlsMatch(
            'https://bestfreepdftools.com/pdf/pdf-editor/',
            'https://bestfreepdftools.com/blog/how-to-edit-pdf',
          ),
          isFalse,
        );
      },
    );

    test('Computes target URL match status labels accurately', () {
      expect(
        UrlValidator.computeUrlMatchStatus(
          'https://bestfreepdftools.com/pdf/pdf-editor/',
          'https://bestfreepdftools.com/pdf/pdf-editor',
        ),
        equals('matches_target'),
      );

      expect(
        UrlValidator.computeUrlMatchStatus(
          'https://bestfreepdftools.com/pdf/pdf-editor/',
          'https://bestfreepdftools.com/tools/other',
        ),
        equals('different_page'),
      );

      expect(
        UrlValidator.computeUrlMatchStatus(
          null,
          'https://bestfreepdftools.com/pdf/pdf-editor',
        ),
        equals('no_target_set'),
      );

      expect(
        UrlValidator.computeUrlMatchStatus(
          'https://bestfreepdftools.com/pdf/pdf-editor',
          null,
        ),
        equals('no_ranking_url'),
      );
    });
  });

  group('Search Performance Sync SQLite Integration Tests', () {
    late String testDbPath;
    late Database db;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp(
        'rankscope_perf_test_',
      );
      testDbPath = '${tempDir.path}/test_perf.db';
      db = await AppDatabase.instance.initCustom(testDbPath);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      try {
        final f = File(testDbPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });

    test('Correlates cached GSC & Bing metrics, updates keywords, and records observations', () async {
      final now = DateTime.now();

      // 1. Insert test website
      final siteId = await db.insert(DatabaseConstants.tableWebsites, {
        'domain': 'bestfreepdftools.com',
        'label': 'Best Free PDF Tools',
        'is_competitor': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // 2. Insert cached GSC search analytics rows
      await db.insert(DatabaseConstants.tableGscSearchAnalytics, {
        'website_id': siteId,
        'query': 'pdf editor',
        'page_url': 'https://bestfreepdftools.com/pdf/pdf-editor/',
        'country_code': 'all',
        'device_type': 'all',
        'metric_date': '2026-10-29',
        'clicks': 42,
        'impressions': 1250,
        'ctr': 0.0336,
        'average_position': 12.4,
        'synced_at': now.millisecondsSinceEpoch,
      });

      await db.insert(DatabaseConstants.tableGscSearchAnalytics, {
        'website_id': siteId,
        'query': 'compress pdf',
        'page_url': 'https://bestfreepdftools.com/tools/all-in-one',
        'country_code': 'all',
        'device_type': 'all',
        'metric_date': '2026-10-29',
        'clicks': 18,
        'impressions': 600,
        'ctr': 0.03,
        'average_position': 7.1,
        'synced_at': now.millisecondsSinceEpoch,
      });

      // 3. Insert cached Bing search analytics rows
      await db.insert(DatabaseConstants.tableBingSearchAnalytics, {
        'website_id': siteId,
        'query': 'pdf editor',
        'page_url': 'https://bestfreepdftools.com/pdf/pdf-editor/',
        'metric_date': '2026-10-29',
        'clicks': 15,
        'impressions': 350,
        'ctr': 0.0428,
        'average_position': 8.2,
        'synced_at': now.millisecondsSinceEpoch,
      });

      // 4. Insert saved keywords
      final kwDataSource = LocalKeywordsDatasource();
      final kw1 = await kwDataSource.insertKeyword(
        Keyword(
          websiteId: siteId,
          keywordText: 'pdf editor',
          targetUrl: 'https://bestfreepdftools.com/pdf/pdf-editor/',
          createdAt: now,
        ),
      );

      final kw2 = await kwDataSource.insertKeyword(
        Keyword(
          websiteId: siteId,
          keywordText: 'compress pdf',
          targetUrl: 'https://bestfreepdftools.com/compress/',
          createdAt: now,
        ),
      );

      final kw3 = await kwDataSource.insertKeyword(
        Keyword(
          websiteId: siteId,
          keywordText: 'unranked free tool',
          targetUrl: 'https://bestfreepdftools.com/unranked/',
          createdAt: now,
        ),
      );

      // 5. Run Search Performance Sync
      final syncService = SearchPerformanceSyncService();
      final syncResult = await syncService.syncPerformanceForWebsite(
        websiteId: siteId,
        domain: 'bestfreepdftools.com',
      );

      expect(syncResult.totalKeywords, equals(3));
      expect(syncResult.matchedKeywords, equals(2));

      // 6. Verify Keyword 1 ('pdf editor'): Matched both GSC & Bing, matches target URL
      final updatedKw1 = await kwDataSource.getKeywordById(kw1.id!);
      expect(updatedKw1, isNotNull);
      expect(updatedKw1!.googleAveragePosition, equals(12.4));
      expect(
        updatedKw1.googleRankingUrl,
        equals('https://bestfreepdftools.com/pdf/pdf-editor/'),
      );
      expect(updatedKw1.googleClicks, equals(42));
      expect(updatedKw1.googleImpressions, equals(1250));
      expect(updatedKw1.bingAveragePosition, equals(8.2));
      expect(updatedKw1.bingClicks, equals(15));
      expect(updatedKw1.bingImpressions, equals(350));
      expect(updatedKw1.urlMatchStatus, equals('matches_target'));

      // 7. Verify Keyword 2 ('compress pdf'): Different page ranking
      final updatedKw2 = await kwDataSource.getKeywordById(kw2.id!);
      expect(updatedKw2, isNotNull);
      expect(updatedKw2!.googleAveragePosition, equals(7.1));
      expect(
        updatedKw2.googleRankingUrl,
        equals('https://bestfreepdftools.com/tools/all-in-one'),
      );
      expect(updatedKw2.urlMatchStatus, equals('different_page'));

      // 8. Verify Keyword 3 ('unranked free tool'): No data, position is null, never 0
      final updatedKw3 = await kwDataSource.getKeywordById(kw3.id!);
      expect(updatedKw3, isNotNull);
      expect(updatedKw3!.googleAveragePosition, isNull);
      expect(updatedKw3.bingAveragePosition, isNull);
      expect(updatedKw3.latestPosition, isNull);

      // 9. Verify historical observations inserted into rank_observations
      final obsList = await kwDataSource.getObservationsForKeyword(kw1.id!);
      expect(obsList.length, equals(2));
      final gscObs = obsList.firstWhere((o) => o.source == 'gsc');
      expect(gscObs.averagePosition, equals(12.4));
      expect(gscObs.clicks, equals(42));
      expect(gscObs.impressions, equals(1250));

      final bingObs = obsList.firstWhere((o) => o.source == 'bing_api');
      expect(bingObs.averagePosition, equals(8.2));
      expect(bingObs.clicks, equals(15));
      expect(bingObs.impressions, equals(350));
    });

    test('Correlates single keyword immediately on creation', () async {
      final now = DateTime.now();

      final siteId = await db.insert(DatabaseConstants.tableWebsites, {
        'domain': 'bestfreepdftools.com',
        'label': 'Best Free PDF Tools',
        'is_competitor': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Pre-populate GSC analytics
      await db.insert(DatabaseConstants.tableGscSearchAnalytics, {
        'website_id': siteId,
        'query': 'pdf editor',
        'page_url': 'https://bestfreepdftools.com/pdf/pdf-editor/',
        'country_code': 'all',
        'device_type': 'all',
        'metric_date': '2026-10-29',
        'clicks': 99,
        'impressions': 3200,
        'ctr': 0.0309,
        'average_position': 4.5,
        'synced_at': now.millisecondsSinceEpoch,
      });

      final repo = KeywordsRepositoryImpl();
      final created = await repo.addKeyword(
        Keyword(
          websiteId: siteId,
          keywordText: 'pdf editor',
          targetUrl: 'https://bestfreepdftools.com/pdf/pdf-editor/',
          createdAt: now,
        ),
      );

      // Immediately has GSC average position and matching URL
      expect(created.googleAveragePosition, equals(4.5));
      expect(created.googleClicks, equals(99));
      expect(created.googleImpressions, equals(3200));
      expect(created.urlMatchStatus, equals('matches_target'));
    });
  });

  group('Overview Screen Rendering Tests', () {
    testWidgets(
      'DashboardView displays Google and Bing average positions and target match',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final now = DateTime.now();
        final testWebsite = Website(
          id: 1,
          domain: 'bestfreepdftools.com',
          label: 'Best Free PDF Tools',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        );

        final testKeywords = [
          Keyword(
            id: 101,
            websiteId: 1,
            keywordText: 'pdf editor',
            targetUrl: 'https://bestfreepdftools.com/pdf/pdf-editor/',
            googleAveragePosition: 12.4,
            googleRankingUrl: 'https://bestfreepdftools.com/pdf/pdf-editor/',
            googleClicks: 42,
            googleImpressions: 1250,
            googleCtr: 0.0336,
            googleSyncedAt: now,
            bingAveragePosition: 8.2,
            bingRankingUrl: 'https://bestfreepdftools.com/pdf/pdf-editor/',
            bingClicks: 15,
            bingImpressions: 350,
            bingCtr: 0.0428,
            bingSyncedAt: now,
            urlMatchStatus: 'matches_target',
            createdAt: now,
          ),
          Keyword(
            id: 102,
            websiteId: 1,
            keywordText: 'compress pdf',
            targetUrl: 'https://bestfreepdftools.com/compress/',
            googleAveragePosition: 7.1,
            googleRankingUrl: 'https://bestfreepdftools.com/tools/other',
            googleClicks: 18,
            googleImpressions: 600,
            urlMatchStatus: 'different_page',
            createdAt: now,
          ),
          Keyword(
            id: 103,
            websiteId: 1,
            keywordText: 'unranked tool',
            targetUrl: 'https://bestfreepdftools.com/unranked/',
            createdAt: now,
          ),
        ];

        final fakeRepo = _TestKeywordsRepository(testKeywords);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              websitesProvider.overrideWith(
                () => _FakeWebsitesNotifier([testWebsite]),
              ),
              selectedWebsiteIdProvider.overrideWith(
                () => _TestSelectedWebsiteIdNotifier(1),
              ),
              keywordsRepositoryProvider.overrideWithValue(fakeRepo),
              googleConfiguredProvider.overrideWith(
                (ref) => Future.value(true),
              ),
              bingConfiguredProvider.overrideWith((ref) => Future.value(true)),
              yandexConfiguredProvider.overrideWith((ref) => Future.value(false)),
              dashboardTrendProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: const MaterialApp(home: DashboardView()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Screen Title & Main Action Elements
        expect(find.text('RankScope'), findsOneWidget);
        expect(find.text('Search Performance Sync'), findsOneWidget);
        expect(find.text('Sync Performance'), findsOneWidget);

        // Verify Engine Status Chips
        expect(find.text('Google Search Console: Connected'), findsOneWidget);
        expect(find.text('Bing Webmaster: Connected'), findsOneWidget);

        // Verify Keywords listed
        expect(find.text('pdf editor'), findsOneWidget);
        expect(find.text('compress pdf'), findsOneWidget);
        expect(find.text('unranked tool'), findsOneWidget);

        // Verify Google & Bing Average Position values
        expect(find.text('12.4'), findsOneWidget); // Google avg pos
        expect(find.text('8.2'), findsOneWidget); // Bing avg pos
        expect(find.text('7.1'), findsOneWidget); // Google avg pos for kw2

        // Verify Target URL Matching Badges
        expect(find.text('Matches Target Landing Page'), findsNWidgets(2));
        expect(
          find.text('Different Page Ranking (Expected Target Not Ranking)'),
          findsOneWidget,
        );

        // Verify Unranked tool displays "No Impressions Yet", never 0
        expect(find.text('No Impressions Yet'), findsAtLeastNWidgets(1));
      },
    );
  });
}

class _FakeWebsitesNotifier extends WebsitesNotifier {
  final List<Website> _sites;
  _FakeWebsitesNotifier(this._sites);

  @override
  Future<List<Website>> build() async => _sites;
}

class _TestSelectedWebsiteIdNotifier extends SelectedWebsiteIdNotifier {
  final int? _initialId;
  _TestSelectedWebsiteIdNotifier(this._initialId);

  @override
  int? build() => _initialId;
}

class _TestKeywordsRepository implements KeywordsRepository {
  final List<Keyword> _keywords;
  _TestKeywordsRepository(this._keywords);

  @override
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? searchEngine,
    String? tag,
  }) async {
    return _keywords.where((k) => k.websiteId == websiteId).toList();
  }

  @override
  Future<Keyword?> getKeywordById(int id) async {
    return _keywords.firstWhere((k) => k.id == id);
  }

  @override
  Future<Keyword?> findDuplicateKeyword({
    required int websiteId,
    required String keywordText,
    required String searchEngine,
    required String targetCountry,
    String? targetCity,
    String language = 'en',
    String device = 'Desktop',
    int? excludeId,
  }) async => null;

  @override
  Future<Keyword> addKeyword(Keyword keyword) async => keyword;

  @override
  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords) async =>
      keywords;

  @override
  Future<void> updateKeyword(Keyword keyword) async {}

  @override
  Future<void> toggleActiveStatus(int keywordId, bool isActive) async {}

  @override
  Future<void> deleteKeyword(int id) async {}

  @override
  Future<void> bulkDeleteKeywords(List<int> ids) async {}

  @override
  Future<RankObservation> recordObservation(
    RankObservation observation,
  ) async => observation;

  @override
  Future<List<RankObservation>> getObservationsForKeyword(
    int keywordId, {
    String? searchEngine,
    int limit = 100,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCannibalizationAlerts(
    int websiteId,
  ) async => [];

  @override
  Future<Keyword> correlateSingleKeyword(Keyword keyword) async => keyword;

  @override
  Future<SearchSyncResult> syncPerformanceForWebsite({
    required int websiteId,
    required String domain,
  }) async => SearchSyncResult(
    totalKeywords: _keywords.length,
    matchedKeywords: 2,
    googleQueriesAvailable: 2,
    bingQueriesAvailable: 1,
    googleConnected: true,
    bingConnected: true,
  );
}
