import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/dashboard/presentation/controllers/dashboard_trend_controller.dart';
import 'package:rankscope/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/manual_tracking/presentation/views/manual_tracking_view.dart';
import 'package:rankscope/features/search_console/presentation/views/search_console_view.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';

import '../../test_helper.dart';

class _FakeWebsitesNotifier extends WebsitesNotifier {
  final List<Website> _initial;
  _FakeWebsitesNotifier(this._initial);

  @override
  Future<List<Website>> build() async => _initial;

  void updateWebsites(List<Website> updated) {
    state = AsyncData(updated);
  }
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
  }) async => const SearchSyncResult(
    totalKeywords: 0,
    matchedKeywords: 0,
    googleQueriesAvailable: 0,
    bingQueriesAvailable: 0,
    googleConnected: false,
    bingConnected: false,
  );
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  final now = DateTime.now();
  final testSiteA = Website(
    id: 1,
    domain: 'site-a.com',
    label: 'Site Alpha',
    createdAt: now,
    updatedAt: now,
  );
  final testSiteB = Website(
    id: 2,
    domain: 'site-b.com',
    label: 'Site Beta',
    isCompetitor: true,
    createdAt: now,
    updatedAt: now,
  );

  group('WebsiteListExtension Safe Lookup Logic', () {
    test('1. Empty website list returns null', () {
      final List<Website> empty = [];
      expect(empty.findActive(null), isNull);
      expect(empty.findActive(1), isNull);
      expect(empty.findById(1), isNull);
    });

    test('2. One website in list resolves correctly', () {
      final List<Website> single = [testSiteA];
      expect(single.findActive(null), testSiteA);
      expect(single.findActive(1), testSiteA);
      expect(single.findActive(999), testSiteA); // falls back safely to first
    });

    test('3. Multiple websites with null selectedId defaults to first', () {
      final List<Website> multiple = [testSiteA, testSiteB];
      expect(multiple.findActive(null), testSiteA);
    });

    test(
      '4. Multiple websites with existing selectedId resolves exact site',
      () {
        final List<Website> multiple = [testSiteA, testSiteB];
        expect(multiple.findActive(2), testSiteB);
        expect(multiple.findActive(1), testSiteA);
      },
    );

    test('5. Multiple websites with non-existent selectedId safely falls back to first without throwing', () {
      final List<Website> multiple = [testSiteA, testSiteB];
      expect(multiple.findActive(99999), testSiteA);
    });
  });

  group('Screen Rendering & Regression Protection Tests', () {
    Widget buildTestHarness({
      required Widget child,
      required List<Website> websites,
      int? selectedId,
      _FakeWebsitesNotifier? customNotifier,
    }) {
      return ProviderScope(
        overrides: [
          websitesProvider.overrideWith(
            () => customNotifier ?? _FakeWebsitesNotifier(websites),
          ),
          selectedWebsiteIdProvider.overrideWith(
            () => _TestSelectedWebsiteIdNotifier(selectedId),
          ),
          keywordsRepositoryProvider.overrideWithValue(
            _FakeKeywordsRepository(),
          ),
          googleConfiguredProvider.overrideWith((ref) async => false),
          bingConfiguredProvider.overrideWith((ref) async => false),
          yandexConfiguredProvider.overrideWith((ref) async => false),
          dashboardTrendProvider.overrideWith((ref, args) async => []),
          gscMetricsFutureProvider.overrideWith((ref, id) async => []),
          gscAggregatesFutureProvider.overrideWith(
            (ref, id) async => {
              'clicks': 0,
              'impressions': 0,
              'avg_ctr': 0.0,
              'avg_position': 0.0,
            },
          ),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets(
      'DashboardView renders with empty website list without crashing',
      (tester) async {
        await tester.pumpWidget(
          buildTestHarness(child: const DashboardView(), websites: []),
        );
        await tester.pumpAndSettle();
        expect(find.text('No Websites Tracked'), findsOneWidget);
      },
    );

    testWidgets('DashboardView renders with one website without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestHarness(child: const DashboardView(), websites: [testSiteA]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Site Alpha'), findsOneWidget);
    });

    testWidgets(
      'DashboardView renders with multiple websites and non-existent selectedId without crashing',
      (tester) async {
        await tester.pumpWidget(
          buildTestHarness(
            child: const DashboardView(),
            websites: [testSiteA, testSiteB],
            selectedId: 8888, // non-existent
          ),
        );
        await tester.pumpAndSettle();
        // Should fall back to first site without throwing runtime error
        expect(find.text('Site Alpha'), findsOneWidget);
      },
    );

    testWidgets(
      'ManualTrackingView renders with empty website list without crashing',
      (tester) async {
        await tester.pumpWidget(
          buildTestHarness(child: const ManualTrackingView(), websites: []),
        );
        await tester.pumpAndSettle();
        expect(find.text('No Properties Available'), findsOneWidget);
      },
    );

    testWidgets('ManualTrackingView renders with websites without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: const ManualTrackingView(),
          websites: [testSiteA, testSiteB],
          selectedId: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ManualTrackingView), findsOneWidget);
      expect(find.text('Search keywords in site-b.com...'), findsOneWidget);
    });

    testWidgets(
      'SearchConsoleView renders with empty website list without crashing',
      (tester) async {
        await tester.pumpWidget(
          buildTestHarness(child: const SearchConsoleView(), websites: []),
        );
        await tester.pumpAndSettle();
        expect(find.text('No Website Selected'), findsOneWidget);
      },
    );

    testWidgets(
      'SearchConsoleView renders with websites and non-existent selectedId without crashing',
      (tester) async {
        await tester.pumpWidget(
          buildTestHarness(
            child: const SearchConsoleView(),
            websites: [testSiteA, testSiteB],
            selectedId: 9999,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SearchConsoleView), findsOneWidget);
        expect(
          find.textContaining('Google Search Console average position'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '6. Screen updates reactively when website list changes after loading',
      (tester) async {
        final notifier = _FakeWebsitesNotifier([testSiteA]);
        await tester.pumpWidget(
          buildTestHarness(
            child: const DashboardView(),
            websites: [testSiteA],
            customNotifier: notifier,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Site Alpha'), findsOneWidget);

        // Simulate website list dynamically changing after load (e.g. new website added)
        notifier.updateWebsites([testSiteA, testSiteB]);
        await tester.pumpAndSettle();
        expect(find.text('Site Alpha'), findsOneWidget);

        // Simulate all websites deleted
        notifier.updateWebsites([]);
        await tester.pumpAndSettle();
        expect(find.text('No Websites Tracked'), findsOneWidget);
      },
    );
  });
}
