import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/errors/exceptions.dart';
import 'package:rankscope/features/backup_restore/data/services/backup_restore_service.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keywords_datasource.dart';
import 'package:rankscope/features/keywords/data/models/keyword_model.dart';
import 'package:rankscope/features/websites/data/datasources/local_websites_datasource.dart';
import 'package:rankscope/features/websites/data/models/website_model.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
    setupMockSecureStorage();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('BackupRestoreService Encrypted System', () {
    test(
      '1. Export, Inspect, Decrypt, Full Restore and Merge Import',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'rankscope_backup_test_',
        );
        final dbPath = '${tempDir.path}/live_test.db';

        try {
          await AppDatabase.instance.initCustom(dbPath);
          final websitesDs = LocalWebsitesDatasource();
          final keywordsDs = LocalKeywordsDatasource();
          final backupService = BackupRestoreService();

          final now = DateTime.now();
          final site = await websitesDs.insertWebsite(
            WebsiteModel(
              domain: 'primary-brand.com',
              label: 'Primary Brand',
              isCompetitor: false,
              createdAt: now,
              updatedAt: now,
            ),
          );

          final kw1 = await keywordsDs.insertKeyword(
            KeywordModel(
              websiteId: site.id!,
              keywordText: 'enterprise seo',
              targetCountry: 'US',
              createdAt: now,
            ),
          );
          expect(kw1.id, isNotNull);

          const password = 'StrongMasterPassword2026!';

          // 1. Export backup
          final backupFile = await backupService.exportEncryptedBackup(
            password: password,
            destinationDirPath: tempDir.path,
          );
          expect(await backupFile.exists(), true);
          expect(backupFile.path.endsWith('.rankscope'), true);

          // Verify the file is encrypted (ciphertext is present, cleartext domain is NOT in file)
          final rawContent = await backupFile.readAsString();
          expect(rawContent.contains('primary-brand.com'), false);
          expect(rawContent.contains('rankscope_encrypted_backup'), true);

          // 2. Inspect with wrong password -> throws ValidationException
          expect(
            () => backupService.inspectAndDecryptBackup(
              filePath: backupFile.path,
              password: 'WrongPassword!',
            ),
            throwsA(isA<ValidationException>()),
          );

          // 3. Inspect with correct password -> inspects preview stats
          final preview = await backupService.inspectAndDecryptBackup(
            filePath: backupFile.path,
            password: password,
          );
          expect(preview['websites_count'], 1);
          expect(preview['keywords_count'], 1);

          // 4. Test Full Restore
          // Clear or insert new dummy site
          await websitesDs.insertWebsite(
            WebsiteModel(
              domain: 'dummy-site.org',
              label: 'Temporary Site',
              createdAt: now,
              updatedAt: now,
            ),
          );
          var currentSites = await websitesDs.getWebsites();
          expect(currentSites.length, 2);

          // Perform full restore with original backup payload
          await backupService.performFullRestore(
            preview['payload'] as Map<String, dynamic>,
          );

          // Verify state is fully restored to backup (dummy site wiped, primary brand restored)
          currentSites = await websitesDs.getWebsites();
          expect(currentSites.length, 1);
          expect(currentSites.first.domain, 'primary-brand.com');
          final currentKeywords = await keywordsDs.getKeywordsByWebsite(
            currentSites.first.id!,
          );
          expect(currentKeywords.length, 1);
          expect(currentKeywords.first.keywordText, 'enterprise seo');

          // 5. Test Merge Import
          // Add a local site before merge
          await websitesDs.insertWebsite(
            WebsiteModel(
              domain: 'local-added.com',
              label: 'Local Added Site',
              createdAt: now,
              updatedAt: now,
            ),
          );

          // Create a separate backup containing competitor.com
          final competitorSite = await websitesDs.insertWebsite(
            WebsiteModel(
              domain: 'competitor.com',
              label: 'Competitor Site',
              isCompetitor: true,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await keywordsDs.insertKeyword(
            KeywordModel(
              websiteId: competitorSite.id!,
              keywordText: 'competitor keyword',
              createdAt: now,
            ),
          );

          final secondBackup = await backupService.exportEncryptedBackup(
            password: password,
            destinationDirPath: tempDir.path,
          );
          final secondPreview = await backupService.inspectAndDecryptBackup(
            filePath: secondBackup.path,
            password: password,
          );

          // Reset database to only have local-added.com
          final db = await AppDatabase.instance.database;
          await db.delete('keywords');
          await db.delete('websites');
          await websitesDs.insertWebsite(
            WebsiteModel(
              domain: 'local-added.com',
              label: 'Local Added Site',
              createdAt: now,
              updatedAt: now,
            ),
          );

          // Run merge import
          final mergeStats = await backupService.performMergeImport(
            secondPreview['payload'] as Map<String, dynamic>,
          );
          expect(
            mergeStats['websites_added'],
            2,
          ); // primary-brand.com and competitor.com added
          expect(mergeStats['keywords_added'], 2);

          final mergedSites = await websitesDs.getWebsites();
          expect(
            mergedSites.length,
            3,
          ); // local-added.com + primary-brand.com + competitor.com
        } finally {
          await AppDatabase.instance.close();
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      },
    );

    test(
      '2. Credential Inclusion Toggle & Yandex Search Analytics Ingestion in Backups',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'rankscope_backup_creds_test_',
        );
        final dbPath = '${tempDir.path}/creds_test.db';

        try {
          await AppDatabase.instance.initCustom(dbPath);
          final websitesDs = LocalWebsitesDatasource();
          final backupService = BackupRestoreService();
          final db = await AppDatabase.instance.database;

          final now = DateTime.now();
          final site = await websitesDs.insertWebsite(
            WebsiteModel(
              domain: 'yandex-test.com',
              label: 'Yandex Test',
              yandexHostId: 'https:yandex-test.com:443',
              createdAt: now,
              updatedAt: now,
            ),
          );

          // Insert Yandex Analytics Record
          await db.insert('yandex_search_analytics', {
            'website_id': site.id!,
            'query': 'yandex search query',
            'metric_date': '2026-10-31',
            'clicks': 42,
            'impressions': 1000,
            'ctr': 0.042,
            'average_position': 3.4,
            'synced_at': now.millisecondsSinceEpoch,
          });

          const pwd = 'CredPassword2026!';

          // Export with includeCredentials: false
          final backupNoCreds = await backupService.exportEncryptedBackup(
            password: pwd,
            includeCredentials: false,
            destinationDirPath: tempDir.path,
          );
          final previewNoCreds = await backupService.inspectAndDecryptBackup(
            filePath: backupNoCreds.path,
            password: pwd,
          );
          expect(previewNoCreds['integrations_count'], 0);
          expect(previewNoCreds['ranking_records_count'], 1); // 1 yandex record

          // Export with includeCredentials: true
          final backupWithCreds = await backupService.exportEncryptedBackup(
            password: pwd,
            includeCredentials: true,
            destinationDirPath: tempDir.path,
          );
          final previewWithCreds = await backupService.inspectAndDecryptBackup(
            filePath: backupWithCreds.path,
            password: pwd,
          );
          expect(previewWithCreds['ranking_records_count'], 1);

          // Clear database and perform Full Restore
          await db.delete('yandex_search_analytics');
          await db.delete('websites');

          await backupService.performFullRestore(
            previewWithCreds['payload'] as Map<String, dynamic>,
          );

          final restoredYandex = await db.query('yandex_search_analytics');
          expect(restoredYandex.length, 1);
          expect(restoredYandex.first['query'], 'yandex search query');
          expect(restoredYandex.first['clicks'], 42);
        } finally {
          await AppDatabase.instance.close();
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      },
    );
  });
}
