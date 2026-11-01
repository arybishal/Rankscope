import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keyword_groups_datasource.dart';
import 'package:rankscope/features/keywords/data/datasources/local_keywords_datasource.dart';
import 'package:rankscope/features/keywords/data/datasources/local_ranking_alerts_datasource.dart';
import 'package:rankscope/features/keywords/data/services/keyword_analysis_service.dart';
import 'package:rankscope/features/keywords/domain/entities/cannibalization_finding.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword_group.dart';
import 'package:rankscope/features/keywords/domain/entities/rank_observation.dart';
import 'package:rankscope/features/keywords/domain/entities/ranking_alert.dart';
import 'package:rankscope/features/keywords/domain/models/alert_settings.dart';
import 'package:rankscope/features/websites/data/datasources/local_websites_datasource.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  late LocalKeywordGroupsDatasource groupsDatasource;
  late LocalKeywordsDatasource keywordsDatasource;
  late LocalRankingAlertsDatasource alertsDatasource;
  late LocalWebsitesDatasource websitesDatasource;
  late KeywordAnalysisService analysisService;
  late Website testSite;

  setUp(() async {
    await AppDatabase.instance.initCustom(inMemoryDatabasePath);
    groupsDatasource = LocalKeywordGroupsDatasource();
    keywordsDatasource = LocalKeywordsDatasource();
    alertsDatasource = LocalRankingAlertsDatasource();
    websitesDatasource = LocalWebsitesDatasource();
    analysisService = const KeywordAnalysisService();

    final now = DateTime.now();
    testSite = await websitesDatasource.insertWebsite(
      Website(
        domain: 'rankscope-test.com',
        label: 'Test Site',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('Phase 2: Keyword Groups & Tags', () {
    test('Create, read, update, and delete keyword group', () async {
      final now = DateTime.now();
      final group = await groupsDatasource.createGroup(
        KeywordGroup(
          websiteId: testSite.id!,
          name: 'Core Money Keywords',
          colorHex: '#3B82F6',
          description: 'Top revenue drivers',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(group.id, isNotNull);
      expect(group.name, 'Core Money Keywords');
      expect(group.colorHex, '#3B82F6');

      // Fetch groups
      final list = await groupsDatasource.getGroupsByWebsite(testSite.id!);
      expect(list.length, 1);
      expect(list.first.name, 'Core Money Keywords');

      // Update group
      final count = await groupsDatasource.updateGroup(
        group.copyWith(name: 'Updated Money Keywords', colorHex: '#10B981'),
      );
      expect(count, 1);

      final fetched = await groupsDatasource.getGroupById(group.id!);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Updated Money Keywords');
      expect(fetched.colorHex, '#10B981');

      // Delete group
      await groupsDatasource.deleteGroup(group.id!);
      final afterDelete = await groupsDatasource.getGroupsByWebsite(testSite.id!);
      expect(afterDelete.isEmpty, isTrue);
    });

    test('Assign keywords to group and verify group-wise performance summaries', () async {
      final now = DateTime.now();
      final group = await groupsDatasource.createGroup(
        KeywordGroup(
          websiteId: testSite.id!,
          name: 'SEO Tools',
          colorHex: '#8B5CF6',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create two keywords
      final kw1 = await keywordsDatasource.insertKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'best rank tracker',
          groupId: group.id,
          googlePosition: 4,
          googleAveragePosition: 4.2,
          googleImpressions: 1000,
          googleClicks: 120,
          googleCtr: 0.12,
          createdAt: now,
        ),
      );

      final kw2 = await keywordsDatasource.insertKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'free serp checker',
          googlePosition: 8,
          googleAveragePosition: 8.4,
          googleImpressions: 500,
          googleClicks: 30,
          googleCtr: 0.06,
          createdAt: now,
        ),
      );

      // Assign kw2 to group as well
      await groupsDatasource.assignKeywordsToGroup([kw2.id!], group.id);

      final groupsWithSummaries = await groupsDatasource.getGroupsByWebsite(testSite.id!);
      expect(groupsWithSummaries.length, 1);

      final summary = groupsWithSummaries.first;
      expect(summary.id, group.id);
      expect(summary.keywordCount, 2);
      expect(summary.totalImpressions, 1500);
      expect(summary.totalClicks, 150);
      expect(summary.averagePosition, closeTo(6.0, 0.01));
      expect(summary.averageCtr, closeTo(0.10, 0.01));

      // Deleting a group sets keywords groupId to null without deleting keywords
      await groupsDatasource.deleteGroup(group.id!);
      final kw1After = await keywordsDatasource.getKeywordById(kw1.id!);
      final kw2After = await keywordsDatasource.getKeywordById(kw2.id!);
      expect(kw1After, isNotNull);
      expect(kw1After!.groupId, isNull);
      expect(kw2After, isNotNull);
      expect(kw2After!.groupId, isNull);
    });
  });

  group('Phase 2: Ranking Alerts System', () {
    test('Create, retrieve, and mark ranking alerts as read', () async {
      final now = DateTime.now();

      final kw = await keywordsDatasource.insertKeyword(
        Keyword(
          websiteId: testSite.id!,
          keywordText: 'alert tracking kw',
          createdAt: now,
        ),
      );

      final alert1 = RankingAlert(
        websiteId: testSite.id!,
        keywordId: kw.id,
        alertType: 'rank_gain',
        severity: 'info',
        title: 'Significant Gain',
        message: 'Position improved by 6 ranks to #3',
        createdAt: now,
      );

      final alert2 = RankingAlert(
        websiteId: testSite.id!,
        keywordId: kw.id,
        alertType: 'rank_drop',
        severity: 'warning',
        title: 'Significant Drop',
        message: 'Position dropped by 7 ranks to #15',
        createdAt: now,
      );

      await alertsDatasource.insertAlertsBatch([alert1, alert2]);

      final allAlerts = await alertsDatasource.getAlertsByWebsite(testSite.id!);
      expect(allAlerts.length, 2);

      final unreadCount = await alertsDatasource.getUnreadCount(testSite.id!);
      expect(unreadCount, 2);

      // Mark first as read
      await alertsDatasource.markAsRead(allAlerts.first.id!);
      final unreadAfterOne = await alertsDatasource.getUnreadCount(testSite.id!);
      expect(unreadAfterOne, 1);

      // Mark all as read
      await alertsDatasource.markAllAsRead(testSite.id!);
      final unreadAfterAll = await alertsDatasource.getUnreadCount(testSite.id!);
      expect(unreadAfterAll, 0);
    });

    test('KeywordAnalysisService.evaluateAlerts triggers expected alerts based on thresholds', () {
      final now = DateTime.now();

      // Keyword 1: Gained from 12 to 5 (diff = 7 >= threshold 5)
      final kwGained = Keyword(
        id: 1,
        websiteId: testSite.id!,
        keywordText: 'gain keyword',
        googlePreviousPosition: 12,
        googlePosition: 5,
        createdAt: now,
      );

      // Keyword 2: Dropped from 4 to 12 (diff = 8 >= threshold 5)
      final kwDropped = Keyword(
        id: 2,
        websiteId: testSite.id!,
        keywordText: 'drop keyword',
        googlePreviousPosition: 4,
        googlePosition: 12,
        createdAt: now,
      );

      // Keyword 3: Mild fluctuation from 5 to 6 (diff = 1 < threshold 5) -> No alert
      final kwStable = Keyword(
        id: 3,
        websiteId: testSite.id!,
        keywordText: 'stable keyword',
        googlePreviousPosition: 5,
        googlePosition: 6,
        createdAt: now,
      );

      // Keyword 4: Previously ranked, now lost
      final kwLost = Keyword(
        id: 4,
        websiteId: testSite.id!,
        keywordText: 'disappeared keyword',
        googlePreviousPosition: 6,
        statusEvent: 'lost',
        createdAt: now,
      );

      const settings = AlertSettings(
        rankGainThreshold: 5,
        rankDropThreshold: 5,
        rankGainEnabled: true,
        rankDropEnabled: true,
        lostQueryEnabled: true,
        urlChangeEnabled: false,
        cannibalizationEnabled: false,
      );

      final generatedAlerts = analysisService.evaluateAlerts(
        websiteId: testSite.id!,
        keywords: [kwGained, kwDropped, kwStable, kwLost],
        observationsByKeywordId: {},
        settings: settings,
      );

      expect(generatedAlerts.length, 3);
      final gainAlert = generatedAlerts.firstWhere((a) => a.keywordId == kwGained.id);
      expect(gainAlert.alertType, 'rank_gain');
      expect(gainAlert.title, contains('Rank Gained'));

      final dropAlert = generatedAlerts.firstWhere((a) => a.keywordId == kwDropped.id);
      expect(dropAlert.alertType, 'rank_drop');
      expect(dropAlert.title, contains('Rank Declined'));

      final lostAlert = generatedAlerts.firstWhere((a) => a.keywordId == kwLost.id);
      expect(lostAlert.alertType, 'lost_query');
    });
  });

  group('Phase 2: Keyword Cannibalization Detection', () {
    test('Accurately detects cannibalization with high confidence when multiple URLs split impressions', () {
      final now = DateTime.now();
      final kw = Keyword(
        id: 101,
        websiteId: testSite.id!,
        keywordText: 'flutter rank tracking',
        targetUrl: 'https://rankscope-test.com/features/rank-tracker',
        createdAt: now,
      );

      // Add observations with two conflicting URLs
      // URL A: 60% impressions
      // URL B: 40% impressions
      final obsList = [
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          position: 4,
          averagePosition: 4.1,
          rankingUrl: 'https://rankscope-test.com/features/rank-tracker',
          impressions: 600,
          clicks: 60,
          ctr: 0.10,
          recordedAt: now.subtract(const Duration(days: 3)),
          source: 'gsc',
        ),
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          position: 5,
          averagePosition: 4.5,
          rankingUrl: 'https://rankscope-test.com/features/rank-tracker',
          impressions: 200,
          clicks: 20,
          ctr: 0.10,
          recordedAt: now.subtract(const Duration(days: 2)),
          source: 'gsc',
        ),
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          position: 5,
          averagePosition: 5.2,
          rankingUrl: 'https://rankscope-test.com/blog/flutter-rank-tracking-guide',
          impressions: 400,
          clicks: 40,
          ctr: 0.10,
          recordedAt: now.subtract(const Duration(days: 1)),
          source: 'gsc',
        ),
      ];

      final findings = analysisService.detectCannibalization(
        keywords: [kw],
        observationsByKeywordId: {kw.id!: obsList},
      );

      expect(findings.length, 1);

      final finding = findings.first;
      expect(finding.keywordText, 'flutter rank tracking');
      expect(finding.affectedUrls.length, 2);
      expect(finding.confidence, CannibalizationConfidence.high);
      final affectedUrlsStrings = finding.affectedUrls.map((u) => u.url).toList();
      expect(
        affectedUrlsStrings,
        containsAll([
          'https://rankscope-test.com/features/rank-tracker',
          'https://rankscope-test.com/blog/flutter-rank-tracking-guide',
        ]),
      );
      final totalImpressions = finding.affectedUrls.fold<int>(0, (sum, u) => sum + u.impressions);
      final totalClicks = finding.affectedUrls.fold<int>(0, (sum, u) => sum + u.clicks);
      expect(totalImpressions, 1200);
      expect(totalClicks, 120);
    });

    test('Does not flag keywords that have only a single consistent ranking URL', () {
      final now = DateTime.now();
      final kw = Keyword(
        id: 102,
        websiteId: testSite.id!,
        keywordText: 'unique topic keyword',
        createdAt: now,
      );

      final obsList = [
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          position: 2,
          rankingUrl: 'https://rankscope-test.com/topic-a',
          impressions: 200,
          clicks: 20,
          recordedAt: now.subtract(const Duration(days: 3)),
        ),
        RankObservation(
          keywordId: kw.id!,
          websiteId: testSite.id!,
          position: 2,
          rankingUrl: 'https://rankscope-test.com/topic-a',
          impressions: 250,
          clicks: 25,
          recordedAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final findings = analysisService.detectCannibalization(
        keywords: [kw],
        observationsByKeywordId: {kw.id!: obsList},
      );

      expect(findings.isEmpty, isTrue);
    });
  });
}
