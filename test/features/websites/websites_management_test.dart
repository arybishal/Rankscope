import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/features/bing_webmaster/presentation/controllers/bing_controller.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keywords_datasource.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/websites/data/datasources/local_websites_datasource.dart';
import 'package:rankscope/features/websites/data/repositories/websites_repository_impl.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/features/websites/presentation/views/websites_management_view.dart';

import '../../test_helper.dart';

void main() {
  late WebsitesRepositoryImpl repository;
  late LocalKeywordsDatasource keywordsDs;

  setUpAll(() {
    setupSqfliteFfi();
  });

  setUp(() async {
    await AppDatabase.instance.initCustom(inMemoryDatabasePath);
    repository = WebsitesRepositoryImpl(
      localDatasource: LocalWebsitesDatasource(),
    );
    keywordsDs = LocalKeywordsDatasource();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('Websites Repository Multi-Website Management Tests', () {
    test('Can register multiple websites with unique domains', () async {
      final now = DateTime.now();

      final site1 = await repository.addWebsite(
        Website(
          domain: 'alpha.com',
          label: 'Alpha Flagship',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final site2 = await repository.addWebsite(
        Website(
          domain: 'beta.com',
          label: 'Beta Store',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final compSite = await repository.addWebsite(
        Website(
          domain: 'competitor.com',
          label: 'Rival Brand',
          isCompetitor: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(site1.id, isNotNull);
      expect(site2.id, isNotNull);
      expect(compSite.id, isNotNull);

      final all = await repository.getWebsites();
      expect(all.length, 3);
      expect(
        all.map((w) => w.domain),
        containsAll(['alpha.com', 'beta.com', 'competitor.com']),
      );
    });

    test('Rejects duplicate domain for same website type', () async {
      final now = DateTime.now();

      await repository.addWebsite(
        Website(
          domain: 'unique-site.org',
          label: 'Primary Site',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(
        () => repository.addWebsite(
          Website(
            domain: 'unique-site.org',
            label: 'Duplicate Attempt',
            isCompetitor: false,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('already registered'),
          ),
        ),
      );
    });

    test(
      'Can update website label and domain without duplicate conflicts',
      () async {
        final now = DateTime.now();

        final created = await repository.addWebsite(
          Website(
            domain: 'original.com',
            label: 'Original Label',
            isCompetitor: false,
            notes: 'Old notes',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final updated = created.copyWith(
          label: 'New Renamed Label',
          notes: 'Updated notes',
        );

        await repository.updateWebsite(updated);

        final fetched = await repository.getWebsiteById(created.id!);
        expect(fetched?.label, 'New Renamed Label');
        expect(fetched?.notes, 'Updated notes');
        expect(fetched?.domain, 'original.com');
      },
    );

    test(
      'Prevents updating a website domain to an existing registered domain',
      () async {
        final now = DateTime.now();

        final site1 = await repository.addWebsite(
          Website(
            domain: 'first.com',
            label: 'First Site',
            isCompetitor: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
        expect(site1.id, isNotNull);

        final site2 = await repository.addWebsite(
          Website(
            domain: 'second.com',
            label: 'Second Site',
            isCompetitor: false,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Attempt to rename site2 to first.com
        expect(
          () => repository.updateWebsite(site2.copyWith(domain: 'first.com')),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              contains('already registered'),
            ),
          ),
        );
      },
    );

    test('Deleting website cascades and removes associated keywords', () async {
      final now = DateTime.now();

      final site = await repository.addWebsite(
        Website(
          domain: 'to-delete.com',
          label: 'Temporary Site',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Add keywords under this website
      final k1 = await keywordsDs.insertKeyword(
        Keyword(
          websiteId: site.id!,
          keywordText: 'best keyword 1',
          createdAt: now,
        ),
      );
      final k2 = await keywordsDs.insertKeyword(
        Keyword(
          websiteId: site.id!,
          keywordText: 'best keyword 2',
          createdAt: now,
        ),
      );

      expect(k1.id, isNotNull);
      expect(k2.id, isNotNull);

      // Verify keywords exist
      final beforeKeywords = await keywordsDs.getKeywordsByWebsite(site.id!);
      expect(beforeKeywords.length, 2);

      // Delete website
      await repository.deleteWebsite(site.id!);

      // Confirm website is deleted
      final checkSite = await repository.getWebsiteById(site.id!);
      expect(checkSite, isNull);

      // Confirm cascading deletion deleted the keywords
      final afterKeywords = await keywordsDs.getKeywordsByWebsite(site.id!);
      expect(afterKeywords, isEmpty);
    });

    test('Multi-website keyword isolation: keywords only belong to their respective website', () async {
      final now = DateTime.now();

      final siteA = await repository.addWebsite(
        Website(
          domain: 'site-a.com',
          label: 'Site A',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final siteB = await repository.addWebsite(
        Website(
          domain: 'site-b.com',
          label: 'Site B',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await keywordsDs.insertKeyword(
        Keyword(
          websiteId: siteA.id!,
          keywordText: 'seo tools for a',
          createdAt: now,
        ),
      );

      await keywordsDs.insertKeyword(
        Keyword(
          websiteId: siteB.id!,
          keywordText: 'analytics for b',
          createdAt: now,
        ),
      );

      final keywordsA = await keywordsDs.getKeywordsByWebsite(siteA.id!);
      final keywordsB = await keywordsDs.getKeywordsByWebsite(siteB.id!);

      expect(keywordsA.length, 1);
      expect(keywordsA.first.keywordText, 'seo tools for a');

      expect(keywordsB.length, 1);
      expect(keywordsB.first.keywordText, 'analytics for b');
    });
  });

  group('WebsitesManagementView UI Tests', () {
    final now = DateTime.now();
    final sampleWebsites = [
      Website(
        id: 1,
        domain: 'primary-site.com',
        label: 'Main Brand',
        isCompetitor: false,
        createdAt: now,
        updatedAt: now,
      ),
      Website(
        id: 2,
        domain: 'competitor-site.com',
        label: 'Competitor Brand',
        isCompetitor: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    testWidgets('Renders website list with filter chips and badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(
              () => _FakeWebsitesNotifier(sampleWebsites),
            ),
            selectedWebsiteIdProvider.overrideWith(
              () => _TestSelectedWebsiteIdNotifier(1),
            ),
            bingPropertyStatusProvider.overrideWith(
              (ref, domain) async => const BingPropertyMatchResult(
                status: BingVerificationStatus.verifiedAndMatched,
                matchedBingUrl: 'https://primary-site.com/',
              ),
            ),
          ],
          child: const MaterialApp(home: WebsitesManagementView()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Websites'), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('My Websites (1)'), findsOneWidget);
      expect(find.text('Competitors (1)'), findsOneWidget);

      expect(find.text('Main Brand'), findsOneWidget);
      expect(find.text('primary-site.com'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      expect(find.text('Competitor Brand'), findsOneWidget);
      expect(find.text('competitor-site.com'), findsOneWidget);
      expect(find.text('Competitor'), findsOneWidget);
    });

    testWidgets('Filtering by Competitors only shows competitor websites', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(
              () => _FakeWebsitesNotifier(sampleWebsites),
            ),
            selectedWebsiteIdProvider.overrideWith(
              () => _TestSelectedWebsiteIdNotifier(1),
            ),
            bingPropertyStatusProvider.overrideWith(
              (ref, domain) async => const BingPropertyMatchResult(
                status: BingVerificationStatus.propertyNotFound,
              ),
            ),
          ],
          child: const MaterialApp(home: WebsitesManagementView()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Competitors (1)' chip
      await tester.tap(find.text('Competitors (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Competitor Brand'), findsOneWidget);
      expect(find.text('Main Brand'), findsNothing);
    });
  });
}

class _FakeWebsitesNotifier extends WebsitesNotifier {
  final List<Website> _initial;
  _FakeWebsitesNotifier(this._initial);

  @override
  Future<List<Website>> build() async => _initial;
}

class _TestSelectedWebsiteIdNotifier extends SelectedWebsiteIdNotifier {
  final int? _initialId;
  _TestSelectedWebsiteIdNotifier(this._initialId);

  @override
  int? build() => _initialId;
}
