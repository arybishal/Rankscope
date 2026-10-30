import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/dialogs/add_keyword_dialog.dart';

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

class _InMemoryKeywordsRepository implements KeywordsRepository {
  final List<Keyword> _keywords;
  _InMemoryKeywordsRepository(this._keywords);

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
  }) async {
    for (final k in _keywords) {
      if (k.websiteId == websiteId &&
          k.keywordText.toLowerCase() == keywordText.trim().toLowerCase() &&
          k.searchEngine == searchEngine &&
          k.targetCountry == targetCountry &&
          k.id != excludeId) {
        return k;
      }
    }
    return null;
  }

  @override
  Future<Keyword> addKeyword(Keyword keyword) async {
    final created = keyword.copyWith(id: _keywords.length + 1);
    _keywords.add(created);
    return created;
  }

  @override
  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords) async {
    final List<Keyword> added = [];
    for (final kw in keywords) {
      added.add(await addKeyword(kw));
    }
    return added;
  }

  @override
  Future<void> updateKeyword(Keyword keyword) async {
    final idx = _keywords.indexWhere((k) => k.id == keyword.id);
    if (idx != -1) _keywords[idx] = keyword;
  }

  @override
  Future<void> toggleActiveStatus(int keywordId, bool isActive) async {
    final idx = _keywords.indexWhere((k) => k.id == keywordId);
    if (idx != -1) _keywords[idx] = _keywords[idx].copyWith(isActive: isActive);
  }

  @override
  Future<void> deleteKeyword(int id) async {
    _keywords.removeWhere((k) => k.id == id);
  }

  @override
  Future<void> bulkDeleteKeywords(List<int> ids) async {
    _keywords.removeWhere((k) => ids.contains(k.id));
  }

  @override
  Future<RankObservation> recordObservation(RankObservation observation) async {
    return observation;
  }

  @override
  Future<List<RankObservation>> getObservationsForKeyword(
    int keywordId, {
    String? searchEngine,
    int limit = 100,
  }) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getCannibalizationAlerts(
    int websiteId,
  ) async {
    return [];
  }
}

void main() {
  group(
    'Phase 1: Keyword Creation Black Screen Bug Fix & Regression Tests',
    () {
      final now = DateTime.now();
      final testWebsite = Website(
        id: 1,
        domain: 'test-seo-site.com',
        label: 'Main Portal',
        createdAt: now,
        updatedAt: now,
      );

      testWidgets(
        'Adding keyword safely closes dialog, preserves dashboard route (no black screen), and updates keyword list immediately',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final fakeKeywordsRepo = _InMemoryKeywordsRepository([
            Keyword(
              id: 1,
              websiteId: 1,
              keywordText: 'existing keyword',
              createdAt: now,
            ),
          ]);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                websitesProvider.overrideWith(
                  () => _FakeWebsitesNotifier([testWebsite]),
                ),
                selectedWebsiteIdProvider.overrideWith(
                  () => _TestSelectedWebsiteIdNotifier(1),
                ),
                keywordsRepositoryProvider.overrideWithValue(fakeKeywordsRepo),
              ],
              child: const MaterialApp(home: DashboardView()),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          // 1. Dashboard mounts and displays initial keyword
          expect(find.text('RankScope'), findsOneWidget);
          expect(find.text('existing keyword'), findsOneWidget);
          expect(find.byType(DashboardView), findsOneWidget);

          // 2. Open Add Keyword dialog
          final addKeywordButton = find.byTooltip('Add Keyword');
          expect(addKeywordButton, findsOneWidget);
          await tester.tap(addKeywordButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // 3. Dialog is mounted
          expect(find.byType(AddKeywordDialog), findsOneWidget);
          expect(find.text('Track New Keyword'), findsOneWidget);

          // 4. Enter search query
          final queryField = find
              .descendant(
                of: find.byType(AddKeywordDialog),
                matching: find.byType(TextField),
              )
              .first;
          await tester.enterText(queryField, 'flutter rank intelligence');
          await tester.pump();

          // 5. Submit form
          final submitButton = find.widgetWithText(
            ElevatedButton,
            'Start Tracking',
          );
          expect(submitButton, findsOneWidget);
          await tester.ensureVisible(submitButton);
          await tester.tap(submitButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();

          // 6. Verify dialog is safely closed
          expect(find.byType(AddKeywordDialog), findsNothing);

          // 7. CRITICAL REGRESSION CHECK:
          // DashboardView MUST remain mounted and rendered (NOT popped to a black screen!)
          expect(find.byType(DashboardView), findsOneWidget);
          expect(find.text('RankScope'), findsOneWidget);

          // 8. Newly added keyword MUST appear immediately without restarting the app!
          expect(find.text('flutter rank intelligence'), findsOneWidget);
          expect(find.text('existing keyword'), findsOneWidget);
        },
      );

      testWidgets('Form validation prevents blank keyword submission', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: AddKeywordDialog(websiteId: 1)),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final submitBtn = find.widgetWithText(ElevatedButton, 'Start Tracking');
        await tester.tap(submitBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Please enter a search query'), findsOneWidget);
      });
    },
  );
}
