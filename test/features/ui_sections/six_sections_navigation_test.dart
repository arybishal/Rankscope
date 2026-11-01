import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/features/analysis/presentation/views/analysis_view.dart';
import 'package:rankscope/features/dashboard/presentation/controllers/dashboard_trend_controller.dart';
import 'package:rankscope/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/keywords/presentation/views/keywords_list_view.dart';
import 'package:rankscope/features/search_engines/presentation/views/search_engines_view.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/routing/app_router.dart';

import '../../test_helper.dart';

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

class _FakeKeywordsRepository implements KeywordsRepository {
  @override
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? searchEngine,
    String? tag,
    int? groupId,
    bool onlyUngrouped = false,
  }) async => [];

  @override
  Future<Keyword?> getKeywordById(int id) async => null;

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
  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords) async => keywords;

  @override
  Future<void> updateKeyword(Keyword keyword) async {}

  @override
  Future<void> deleteKeyword(int id) async {}

  @override
  Future<void> bulkDeleteKeywords(List<int> ids) async {}

  @override
  Future<void> toggleActiveStatus(int id, bool isActive) async {}

  @override
  Future<void> updateKeywordGroup(int keywordId, int? groupId) async {}

  @override
  Future<void> assignKeywordsToGroup(List<int> keywordIds, int? groupId) async {}

  @override
  Future<RankObservation> recordObservation(RankObservation observation) async => observation;

  @override
  Future<List<RankObservation>> getObservationsForKeyword(
    int keywordId, {
    String? searchEngine,
    int limit = 100,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCannibalizationAlerts(int websiteId) async => [];

  @override
  Future<Keyword> correlateSingleKeyword(Keyword keyword) async => keyword;

  @override
  Future<SearchSyncResult> syncPerformanceForWebsite({
    required int websiteId,
    required String domain,
    String? gscPropertyId,
    String? country,
    String? device,
    String? searchType,
  }) async {
    return const SearchSyncResult(
      totalKeywords: 0,
      matchedKeywords: 0,
      googleQueriesAvailable: 0,
      bingQueriesAvailable: 0,
      googleConnected: false,
      bingConnected: false,
    );
  }
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
    setupMockSecureStorage();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  final testSite = Website(
    id: 1,
    domain: 'testsite.com',
    label: 'Test Site',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('6 Primary UI Sections Navigation & State Integration Tests', () {
    testWidgets('Renders all 6 primary navigation destinations', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(() => _FakeWebsitesNotifier([testSite])),
            selectedWebsiteIdProvider.overrideWith(() => _TestSelectedWebsiteIdNotifier(1)),
            keywordsRepositoryProvider.overrideWithValue(_FakeKeywordsRepository()),
            googleConfiguredProvider.overrideWith((ref) async => false),
            bingConfiguredProvider.overrideWith((ref) async => false),
            yandexConfiguredProvider.overrideWith((ref) async => false),
            dashboardTrendProvider.overrideWith((ref, args) async => []),
          ],
          child: MaterialApp.router(
            routerConfig: createAppRouter(initialLocation: '/dashboard'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check navigation destinations
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Keywords'), findsWidgets);
      expect(find.text('Analysis'), findsWidgets);
      expect(find.text('SERP Audit'), findsWidgets);
      expect(find.text('Engines'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('Navigating to /keywords renders KeywordsListView', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(() => _FakeWebsitesNotifier([testSite])),
            selectedWebsiteIdProvider.overrideWith(() => _TestSelectedWebsiteIdNotifier(1)),
            keywordsRepositoryProvider.overrideWithValue(_FakeKeywordsRepository()),
            googleConfiguredProvider.overrideWith((ref) async => false),
            bingConfiguredProvider.overrideWith((ref) async => false),
            yandexConfiguredProvider.overrideWith((ref) async => false),
            dashboardTrendProvider.overrideWith((ref, args) async => []),
          ],
          child: MaterialApp.router(
            routerConfig: createAppRouter(initialLocation: '/keywords'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(KeywordsListView), findsOneWidget);
      expect(find.text('Add Keyword'), findsOneWidget);
    });

    testWidgets('Navigating to /analysis renders AnalysisView', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(() => _FakeWebsitesNotifier([testSite])),
            selectedWebsiteIdProvider.overrideWith(() => _TestSelectedWebsiteIdNotifier(1)),
            keywordsRepositoryProvider.overrideWithValue(_FakeKeywordsRepository()),
            googleConfiguredProvider.overrideWith((ref) async => false),
            bingConfiguredProvider.overrideWith((ref) async => false),
            yandexConfiguredProvider.overrideWith((ref) async => false),
            dashboardTrendProvider.overrideWith((ref, args) async => []),
          ],
          child: MaterialApp.router(
            routerConfig: createAppRouter(initialLocation: '/analysis'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AnalysisView), findsOneWidget);
      expect(find.text('SEO Intelligence & Analysis'), findsOneWidget);
    });

    testWidgets('Navigating to /search-engines renders SearchEnginesView', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(() => _FakeWebsitesNotifier([testSite])),
            selectedWebsiteIdProvider.overrideWith(() => _TestSelectedWebsiteIdNotifier(1)),
            keywordsRepositoryProvider.overrideWithValue(_FakeKeywordsRepository()),
            googleConfiguredProvider.overrideWith((ref) async => true),
            bingConfiguredProvider.overrideWith((ref) async => false),
            yandexConfiguredProvider.overrideWith((ref) async => true),
            dashboardTrendProvider.overrideWith((ref, args) async => []),
          ],
          child: MaterialApp.router(
            routerConfig: createAppRouter(initialLocation: '/search-engines'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SearchEnginesView), findsOneWidget);
      expect(find.text('Search Engines Hub'), findsOneWidget);
      expect(find.text('Google Search Console'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Yandex Webmaster'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Yandex Webmaster'), findsOneWidget);
    });
  });
}
