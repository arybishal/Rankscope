import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/keywords_repository_impl.dart';
import '../../domain/repositories/keywords_repository.dart';

export '../../data/services/search_performance_sync_service.dart';
export '../../domain/entities/keyword.dart';
export '../../domain/entities/rank_observation.dart';
export '../../domain/repositories/keywords_repository.dart';

final keywordsRepositoryProvider = Provider<KeywordsRepository>((ref) {
  return KeywordsRepositoryImpl();
});

class SearchPerformanceSyncState {
  final bool isSyncing;
  final String? errorMessage;
  final SearchSyncResult? lastResult;

  const SearchPerformanceSyncState({
    this.isSyncing = false,
    this.errorMessage,
    this.lastResult,
  });

  SearchPerformanceSyncState copyWith({
    bool? isSyncing,
    String? errorMessage,
    SearchSyncResult? lastResult,
  }) {
    return SearchPerformanceSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class SearchPerformanceSyncNotifier
    extends Notifier<SearchPerformanceSyncState> {
  @override
  SearchPerformanceSyncState build() => const SearchPerformanceSyncState();

  Future<SearchSyncResult?> syncPerformance({
    required int websiteId,
    required String domain,
    String? gscPropertyId,
    String? country,
    String? device,
    String? searchType,
  }) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repo = ref.read(keywordsRepositoryProvider);
      final result = await repo.syncPerformanceForWebsite(
        websiteId: websiteId,
        domain: domain,
        gscPropertyId: gscPropertyId,
        country: country,
        device: device,
        searchType: searchType,
      );

      state = state.copyWith(
        isSyncing: false,
        lastResult: result,
        errorMessage: null,
      );

      // Invalidate keyword list and observation views for instant UI updates
      ref.invalidate(keywordsFamilyProvider(websiteId));
      ref.invalidate(cannibalizationAlertsFamilyProvider(websiteId));

      return result;
    } catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: 'Sync failed: $e');
      return null;
    }
  }
}

final searchPerformanceSyncProvider =
    NotifierProvider<SearchPerformanceSyncNotifier, SearchPerformanceSyncState>(
      () => SearchPerformanceSyncNotifier(),
    );

class KeywordsNotifier extends AsyncNotifier<List<Keyword>> {
  final int websiteId;

  KeywordsNotifier(this.websiteId);

  @override
  Future<List<Keyword>> build() async {
    final repo = ref.watch(keywordsRepositoryProvider);
    return repo.getKeywordsByWebsite(websiteId);
  }

  Future<void> loadKeywords({String? searchEngine}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(keywordsRepositoryProvider);
      return repo.getKeywordsByWebsite(websiteId, searchEngine: searchEngine);
    });
  }

  Future<Keyword> addKeyword({
    required String keywordText,
    String? targetUrl,
    String searchEngine = 'Google',
    String targetCountry = 'GLOBAL',
    String? targetCity,
    String language = 'en',
    String device = 'Desktop',
    List<String> tags = const [],
    bool isActive = true,
  }) async {
    final repo = ref.read(keywordsRepositoryProvider);
    final now = DateTime.now();
    final kw = Keyword(
      websiteId: websiteId,
      keywordText: keywordText.trim(),
      targetUrl: targetUrl?.trim().isEmpty == true ? null : targetUrl?.trim(),
      searchEngine: searchEngine,
      targetCountry: targetCountry.trim().toUpperCase(),
      targetCity: targetCity?.trim().isEmpty == true
          ? null
          : targetCity?.trim(),
      language: language.trim(),
      device: device,
      tags: tags,
      isActive: isActive,
      createdAt: now,
    );
    final created = await repo.addKeyword(kw);
    await loadKeywords();
    return created;
  }

  Future<void> updateKeyword(Keyword keyword) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.updateKeyword(keyword);
    await loadKeywords();
  }

  Future<void> toggleActive(int keywordId, bool isActive) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.toggleActiveStatus(keywordId, isActive);
    await loadKeywords();
  }

  Future<void> deleteKeyword(int id) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.deleteKeyword(id);
    await loadKeywords();
  }

  Future<void> bulkDeleteKeywords(List<int> ids) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.bulkDeleteKeywords(ids);
    await loadKeywords();
  }

  Future<RankObservation> recordObservation(RankObservation observation) async {
    final repo = ref.read(keywordsRepositoryProvider);
    final saved = await repo.recordObservation(observation);
    await loadKeywords();
    ref.invalidate(keywordObservationsFamilyProvider(observation.keywordId));
    ref.invalidate(cannibalizationAlertsFamilyProvider(websiteId));
    return saved;
  }

  Future<SearchSyncResult?> syncPerformance(String domain) async {
    return await ref
        .read(searchPerformanceSyncProvider.notifier)
        .syncPerformance(websiteId: websiteId, domain: domain);
  }
}

final keywordsFamilyProvider =
    AsyncNotifierProvider.family<KeywordsNotifier, List<Keyword>, int>(
      (websiteId) => KeywordsNotifier(websiteId),
    );

final keywordObservationsFamilyProvider =
    FutureProvider.family<List<RankObservation>, int>((ref, keywordId) async {
      final repo = ref.watch(keywordsRepositoryProvider);
      return await repo.getObservationsForKeyword(keywordId);
    });

final cannibalizationAlertsFamilyProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      websiteId,
    ) async {
      final repo = ref.watch(keywordsRepositoryProvider);
      return await repo.getCannibalizationAlerts(websiteId);
    });
