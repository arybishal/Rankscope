import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/manual_tracking/presentation/views/manual_tracking_view.dart';
import 'package:rankscope/features/search_console/domain/utils/gsc_property_matcher.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';

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
  final List<Keyword> _keywords;
  _FakeKeywordsRepository(this._keywords);

  @override
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? searchEngine,
    String? tag,
    int? groupId,
    bool onlyUngrouped = false,
  }) async => _keywords;

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
  }) async => const SearchSyncResult(
    totalKeywords: 1,
    matchedKeywords: 1,
    googleQueriesAvailable: 1,
    bingQueriesAvailable: 0,
    googleConnected: true,
    bingConnected: false,
    googleStatusMessage: 'Synced 1 GSC queries',
  );
}

void main() {
  group('GscPropertyMatcher Tests', () {
    test('normalizes domains accurately', () {
      expect(
        GscPropertyMatcher.normalizeToBareDomain('https://example.com/'),
        'example.com',
      );
      expect(
        GscPropertyMatcher.normalizeToBareDomain('http://www.test-site.org/path'),
        'test-site.org',
      );
      expect(
        GscPropertyMatcher.normalizeToBareDomain('sc-domain:sub.domain.com'),
        'sub.domain.com',
      );
    });

    test('finds exact sc-domain match from verified properties', () {
      final verified = [
        'https://other.com/',
        'sc-domain:mysite.com',
        'https://mysite.com/',
      ];
      final match = GscPropertyMatcher.findMatchingProperty(
        'https://mysite.com',
        verified,
      );
      expect(match, 'sc-domain:mysite.com');
    });

    test('finds url prefix match if no domain property exists', () {
      final verified = [
        'https://another.com/',
        'https://mysite.com/',
      ];
      final match = GscPropertyMatcher.findMatchingProperty(
        'mysite.com',
        verified,
      );
      expect(match, 'https://mysite.com/');
    });
  });

  group('SERP Audit View (ManualTrackingView) Tests', () {
    final testWebsite = Website(
      id: 1,
      domain: 'mybrand.com',
      label: 'My Brand',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final kwWithGsc = Keyword(
      id: 101,
      websiteId: 1,
      keywordText: 'best seo software',
      googleAveragePosition: 4.2,
      googleRankingUrl: 'https://mybrand.com/tools/seo',
      googleImpressions: 1540,
      googleClicks: 82,
      googleCtr: 0.0532,
      googleSyncedAt: DateTime.now(),
      latestPosition: 3,
      positionDelta: 1,
      createdAt: DateTime.now(),
    );

    final kwWithoutGsc = Keyword(
      id: 102,
      websiteId: 1,
      keywordText: 'emerging keyword',
      googleAveragePosition: null,
      googleRankingUrl: null,
      googleImpressions: 0,
      googleClicks: 0,
      googleCtr: 0.0,
      latestPosition: null,
      positionDelta: 0,
      createdAt: DateTime.now(),
    );

    testWidgets(
      'displays Google Search Console Average Position with exact metrics when present',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              websitesProvider.overrideWith(
                () => _FakeWebsitesNotifier([testWebsite]),
              ),
              selectedWebsiteIdProvider.overrideWith(
                () => _TestSelectedWebsiteIdNotifier(1),
              ),
              keywordsRepositoryProvider.overrideWithValue(
                _FakeKeywordsRepository([kwWithGsc]),
              ),
            ],
            child: const MaterialApp(
              home: ManualTrackingView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify exact label: Google Search Console Average Position
        expect(
          find.text('Google Search Console Average Position'),
          findsOneWidget,
        );

        // 2. Verify average position badge
        expect(find.text('Avg #4.2'), findsOneWidget);

        // 3. Verify ranking URL
        expect(find.text('https://mybrand.com/tools/seo'), findsOneWidget);

        // 4. Verify Manual Observation section is distinct
        expect(find.text('Manual Observation'), findsOneWidget);
        expect(find.text('Point-in-time SERP Rank: #3'), findsOneWidget);
      },
    );

    testWidgets(
      'displays "No Google data available" when no impressions or rank exist (NEVER 0)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              websitesProvider.overrideWith(
                () => _FakeWebsitesNotifier([testWebsite]),
              ),
              selectedWebsiteIdProvider.overrideWith(
                () => _TestSelectedWebsiteIdNotifier(1),
              ),
              keywordsRepositoryProvider.overrideWithValue(
                _FakeKeywordsRepository([kwWithoutGsc]),
              ),
            ],
            child: const MaterialApp(
              home: ManualTrackingView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify "No Google data available" is displayed
        expect(find.text('No Google data available'), findsOneWidget);

        // 2. Verify 0 or #0 is NEVER displayed as rank
        expect(find.text('Avg #0'), findsNothing);
        expect(find.text('Avg #0.0'), findsNothing);

        // 3. Verify Manual Observation section shows unlogged state with Log Rank button
        expect(find.text('Manual Observation'), findsOneWidget);
        expect(find.text('No manual observation recorded'), findsOneWidget);
        expect(find.text('Log Rank'), findsOneWidget);
      },
    );
  });
}
