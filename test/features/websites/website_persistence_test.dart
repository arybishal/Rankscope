import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keywords_datasource.dart';
import 'package:rankscope/features/keywords/data/models/keyword_model.dart';
import 'package:rankscope/features/websites/data/datasources/local_websites_datasource.dart';
import 'package:rankscope/features/websites/data/models/website_model.dart';
import 'package:rankscope/features/websites/data/repositories/websites_repository_impl.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('Website Persistence Workflow', () {
    test('1. insertWebsite succeeds and retrieves correctly', () async {
      await AppDatabase.instance.initCustom(inMemoryDatabasePath);
      final datasource = LocalWebsitesDatasource();
      final repo = WebsitesRepositoryImpl(localDatasource: datasource);

      final now = DateTime.now();
      final model = WebsiteModel(
        domain: 'rankscope.dev',
        label: 'RankScope Official',
        isCompetitor: false,
        notes: 'SEO analytics flag',
        createdAt: now,
        updatedAt: now,
      );

      final created = await repo.addWebsite(model);
      expect(created.id, isNotNull);
      expect(created.domain, 'rankscope.dev');

      final list = await repo.getWebsites();
      expect(list.length, 1);
      expect(list.first.label, 'RankScope Official');
    });

    test('2. duplicate domain registration throws ValidationFailure', () async {
      await AppDatabase.instance.initCustom(inMemoryDatabasePath);
      final datasource = LocalWebsitesDatasource();
      final repo = WebsitesRepositoryImpl(localDatasource: datasource);

      final now = DateTime.now();
      final site1 = WebsiteModel(
        domain: 'example.com',
        label: 'Example Primary',
        isCompetitor: false,
        createdAt: now,
        updatedAt: now,
      );
      await repo.addWebsite(site1);

      final siteDuplicate = WebsiteModel(
        domain: 'example.com',
        label: 'Example Duplicate',
        isCompetitor: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => repo.addWebsite(siteDuplicate),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test(
      '3. updateWebsite modifies existing record without creating duplicate',
      () async {
        await AppDatabase.instance.initCustom(inMemoryDatabasePath);
        final datasource = LocalWebsitesDatasource();
        final repo = WebsitesRepositoryImpl(localDatasource: datasource);

        final now = DateTime.now();
        final site = WebsiteModel(
          domain: 'updatetest.com',
          label: 'Original Label',
          notes: 'Original note',
          isCompetitor: false,
          createdAt: now,
          updatedAt: now,
        );
        final created = await repo.addWebsite(site);

        final updated = created.copyWith(
          label: 'Updated Brand Label',
          notes: 'Updated note field',
        );
        await repo.updateWebsite(updated);

        final list = await repo.getWebsites();
        expect(list.length, 1);
        expect(list.first.id, created.id);
        expect(list.first.label, 'Updated Brand Label');
        expect(list.first.notes, 'Updated note field');
      },
    );

    test(
      '4. deleteWebsite cascades and removes associated child keywords',
      () async {
        await AppDatabase.instance.initCustom(inMemoryDatabasePath);
        final websitesDs = LocalWebsitesDatasource();
        final keywordsDs = LocalKeywordsDatasource();
        final repo = WebsitesRepositoryImpl(localDatasource: websitesDs);

        final now = DateTime.now();
        final createdSite = await repo.addWebsite(
          WebsiteModel(
            domain: 'cascadetest.com',
            label: 'Cascade Test',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final keyword = await keywordsDs.insertKeyword(
          KeywordModel(
            websiteId: createdSite.id!,
            keywordText: 'seo tools',
            createdAt: now,
          ),
        );
        expect(keyword.id, isNotNull);

        // Verify keyword exists
        var keywords = await keywordsDs.getKeywordsByWebsite(createdSite.id!);
        expect(keywords.length, 1);

        // Delete website
        await repo.deleteWebsite(createdSite.id!);

        // Verify website deleted
        final websites = await repo.getWebsites();
        expect(websites.isEmpty, true);

        // Verify keywords cascade deleted
        keywords = await keywordsDs.getKeywordsByWebsite(createdSite.id!);
        expect(keywords.isEmpty, true);
      },
    );

    test('5. data persists across database close and reopen', () async {
      final tempDir = Directory.systemTemp.createTempSync('rankscope_db_test_');
      final dbPath = '${tempDir.path}/test_rankscope.db';

      try {
        // Open and insert
        await AppDatabase.instance.initCustom(dbPath);
        final datasource1 = LocalWebsitesDatasource();
        final repo1 = WebsitesRepositoryImpl(localDatasource: datasource1);

        final now = DateTime.now();
        await repo1.addWebsite(
          WebsiteModel(
            domain: 'persistent.org',
            label: 'Persistent Site',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Close database
        await AppDatabase.instance.close();

        // Reopen database
        await AppDatabase.instance.initCustom(dbPath);
        final datasource2 = LocalWebsitesDatasource();
        final repo2 = WebsitesRepositoryImpl(localDatasource: datasource2);

        final sites = await repo2.getWebsites();
        expect(sites.length, 1);
        expect(sites.first.domain, 'persistent.org');
        expect(sites.first.label, 'Persistent Site');
      } finally {
        await AppDatabase.instance.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
