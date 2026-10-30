import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keywords_datasource.dart';
import 'package:rankscope/features/keywords/data/repositories/keywords_repository_impl.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/keywords/domain/entities/rank_observation.dart';
import 'package:rankscope/features/websites/data/datasources/local_websites_datasource.dart';
import 'package:rankscope/features/websites/data/repositories/websites_repository_impl.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  late KeywordsRepositoryImpl repository;
  late WebsitesRepositoryImpl websiteRepo;
  late Website testSite;

  setUp(() async {
    await AppDatabase.instance.initCustom(inMemoryDatabasePath);
    repository = KeywordsRepositoryImpl(
      localDatasource: LocalKeywordsDatasource(),
    );
    websiteRepo = WebsitesRepositoryImpl(
      localDatasource: LocalWebsitesDatasource(),
    );

    final now = DateTime.now();
    testSite = await websiteRepo.addWebsite(
      Website(
        domain: 'rankscope-demo.com',
        label: 'Demo Store',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('Keyword CRUD & Configuration Tests', () {
    test('Adds keyword with complete configuration parameters', () async {
      final now = DateTime.now();
      final kw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'best local flutter seo',
          targetUrl: 'https://rankscope-demo.com/seo',
          searchEngine: 'Google',
          targetCountry: 'US',
          targetCity: 'Chicago',
          language: 'en',
          device: 'Mobile',
          tags: ['core', 'mobile'],
          isActive: true,
          createdAt: now,
        ),
      );

      expect(kw.id, isNotNull);
      expect(kw.keywordText, 'best local flutter seo');
      expect(kw.searchEngine, 'Google');
      expect(kw.targetCountry, 'US');
      expect(kw.targetCity, 'Chicago');
      expect(kw.device, 'Mobile');
      expect(kw.isActive, isTrue);

      final fetched = await repository.getKeywordById(kw.id!);
      expect(fetched, isNotNull);
      expect(fetched?.keywordText, 'best local flutter seo');
      expect(fetched?.tags, containsAll(['core', 'mobile']));
    });

    test('Prevents duplicate keyword under identical configuration', () async {
      final now = DateTime.now();
      await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'rank tracker app',
          searchEngine: 'Google',
          targetCountry: 'GLOBAL',
          createdAt: now,
        ),
      );

      // Same keyword, same engine, same country -> blocked
      expect(
        () => repository.addKeyword(
          Keyword(
            websiteId: testSite.id!,
            keywordText: 'rank tracker app',
            searchEngine: 'Google',
            targetCountry: 'GLOBAL',
            createdAt: now,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Same keyword on Bing -> permitted!
      final bingKw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'rank tracker app',
          searchEngine: 'Bing',
          targetCountry: 'GLOBAL',
          createdAt: now,
        ),
      );
      expect(bingKw.id, isNotNull);

      // Same keyword in different country (US) -> permitted!
      final usKw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'rank tracker app',
          searchEngine: 'Google',
          targetCountry: 'US',
          createdAt: now,
        ),
      );
      expect(usKw.id, isNotNull);
    });

    test(
      'Edits keyword details and preserves tracking configuration integrity',
      () async {
        final now = DateTime.now();
        final kw = await repository.addKeyword(
          Keyword(
            websiteId: testSite.id!,
            keywordText: 'original query',
            targetCountry: 'GLOBAL',
            createdAt: now,
          ),
        );

        final updated = kw.copyWith(
          keywordText: 'updated query',
          targetCountry: 'US',
          targetCity: 'New York',
          device: 'Mobile',
        );

        await repository.updateKeyword(updated);

        final fetched = await repository.getKeywordById(kw.id!);
        expect(fetched?.keywordText, 'updated query');
        expect(fetched?.targetCountry, 'US');
        expect(fetched?.targetCity, 'New York');
        expect(fetched?.device, 'Mobile');
      },
    );

    test('Pauses and resumes tracking via toggleActiveStatus', () async {
      final now = DateTime.now();
      final kw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'pausable query',
          isActive: true,
          createdAt: now,
        ),
      );

      await repository.toggleActiveStatus(kw.id!, false);
      var fetched = await repository.getKeywordById(kw.id!);
      expect(fetched?.isActive, isFalse);

      await repository.toggleActiveStatus(kw.id!, true);
      fetched = await repository.getKeywordById(kw.id!);
      expect(fetched?.isActive, isTrue);
    });

    test('Bulk deletion removes multiple keywords safely', () async {
      final now = DateTime.now();
      final kw1 = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'batch 1',
          createdAt: now,
        ),
      );
      final kw2 = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'batch 2',
          createdAt: now,
        ),
      );
      final kw3 = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'batch 3',
          createdAt: now,
        ),
      );

      await repository.bulkDeleteKeywords([kw1.id!, kw2.id!]);

      final all = await repository.getKeywordsByWebsite(testSite.id!);
      expect(all.length, 1);
      expect(all.first.id, kw3.id);
    });
  });

  group('Ranking URL Detection & URL Switching Tests', () {
    test(
      'Records observation, detects ranking URL, and preserves history',
      () async {
        final now = DateTime.now();
        final kw = await repository.addKeyword(
          Keyword(
            websiteId: testSite.id!,
            keywordText: 'pdf conversion tool',
            searchEngine: 'Google',
            createdAt: now,
          ),
        );

        // Observation 1: ranks #8 on /best-pdf-tools/
        final obs1 = RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 8,
          rankingUrl: 'https://rankscope-demo.com/best-pdf-tools/',
          recordedAt: now.subtract(const Duration(days: 2)),
        );
        await repository.recordObservation(obs1);

        var updatedKw = await repository.getKeywordById(kw.id!);
        expect(updatedKw?.googlePosition, 8);
        expect(
          updatedKw?.rankingUrl,
          'https://rankscope-demo.com/best-pdf-tools/',
        );

        // Observation 2: ranks #5 on /free-pdf-tools/ (URL changed!)
        final obs2 = RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 5,
          rankingUrl: 'https://rankscope-demo.com/free-pdf-tools/',
          recordedAt: now,
        );
        final savedObs2 = await repository.recordObservation(obs2);

        // Verify URL change detection
        expect(savedObs2.isUrlChange, isTrue);
        expect(
          savedObs2.previousRankingUrl,
          'https://rankscope-demo.com/best-pdf-tools/',
        );

        // Verify keyword reflects new ranking URL and rank gain
        updatedKw = await repository.getKeywordById(kw.id!);
        expect(updatedKw?.googlePosition, 5);
        expect(updatedKw?.googleDelta, 3); // 8 - 5 = +3 improvement!
        expect(
          updatedKw?.rankingUrl,
          'https://rankscope-demo.com/free-pdf-tools/',
        );

        // Verify full history is preserved
        final history = await repository.getObservationsForKeyword(kw.id!);
        expect(history.length, 2);
        expect(
          history[0].rankingUrl,
          'https://rankscope-demo.com/free-pdf-tools/',
        );
        expect(
          history[1].rankingUrl,
          'https://rankscope-demo.com/best-pdf-tools/',
        );
      },
    );
  });

  group('Keyword Cannibalization Detection Tests', () {
    test('Flags cannibalization when multiple distinct URLs are observed for the same query', () async {
      final now = DateTime.now();
      final kw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'flutter audit tool',
          searchEngine: 'Google',
          createdAt: now,
        ),
      );

      // Observation 1: URL A
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 12,
          rankingUrl: 'https://rankscope-demo.com/page-a',
          recordedAt: now.subtract(const Duration(days: 3)),
        ),
      );

      // Observation 2: URL B
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 15,
          rankingUrl: 'https://rankscope-demo.com/page-b',
          recordedAt: now.subtract(const Duration(days: 2)),
        ),
      );

      final updatedKw = await repository.getKeywordById(kw.id!);
      expect(updatedKw?.hasCannibalization, isTrue);
      expect([
        'multiple_urls',
        'url_switching',
      ], contains(updatedKw?.cannibalizationStatus));

      final alerts = await repository.getCannibalizationAlerts(testSite.id!);
      expect(alerts.length, 1);
      expect(alerts.first['keyword_id'], kw.id);
      expect(alerts.first['distinct_url_count'], 2);
    });
  });

  group('New, Lost, and Recovered Transitions', () {
    test('Transitions from Unranked -> New -> Lost -> Recovered', () async {
      final now = DateTime.now();
      final kw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'emerging query',
          searchEngine: 'Google',
          createdAt: now,
        ),
      );

      // 1. Initial check: Ranks #18 -> Marks as 'new'
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 18,
          rankingUrl: 'https://rankscope-demo.com/app',
          recordedAt: now.subtract(const Duration(days: 5)),
        ),
      );

      var fetched = await repository.getKeywordById(kw.id!);
      expect(fetched?.isNew, isTrue);
      expect(fetched?.firstRankedAt, isNotNull);

      // 2. Position drops to 0 (confirmed not found) -> Marks as 'lost'
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 0,
          rankingUrl: null,
          observationStatus: 'not_ranking',
          recordedAt: now.subtract(const Duration(days: 2)),
        ),
      );

      fetched = await repository.getKeywordById(kw.id!);
      expect(fetched?.isLost, isTrue);
      expect(fetched?.lostAt, isNotNull);
      expect(fetched?.googlePosition, 0);

      // 3. Ranks again at #9 -> Marks as 'recovered'
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 9,
          rankingUrl: 'https://rankscope-demo.com/app-v2',
          recordedAt: now,
        ),
      );

      fetched = await repository.getKeywordById(kw.id!);
      expect(fetched?.isRecovered, isTrue);
      expect(fetched?.googlePosition, 9);
      expect(fetched?.lostAt, isNull);
    });
  });

  group('Search Engine Separation Tests', () {
    test('Google and Bing positions remain completely isolated for the same keyword', () async {
      final now = DateTime.now();
      final kw = await repository.addKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'cross engine seo',
          createdAt: now,
        ),
      );

      // Observation on Google: #4
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Google',
          position: 4,
          recordedAt: now,
        ),
      );

      // Observation on Bing: #12
      await repository.recordObservation(
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          searchEngine: 'Bing',
          position: 12,
          recordedAt: now,
        ),
      );

      final fetched = await repository.getKeywordById(kw.id!);
      expect(fetched?.googlePosition, 4);
      expect(fetched?.bingPosition, 12);
      expect(fetched?.positionFor('Google'), 4);
      expect(fetched?.positionFor('Bing'), 12);
    });
  });
}
