import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../data/datasources/local_keyword_groups_datasource.dart';
import '../../data/datasources/local_ranking_alerts_datasource.dart';
import '../../data/repositories/keywords_repository_impl.dart';
import '../../data/services/keyword_analysis_service.dart';
import '../../domain/entities/cannibalization_finding.dart';
import '../../domain/entities/keyword_group.dart';
import '../../domain/entities/ranking_alert.dart';
import '../../domain/models/alert_settings.dart';
import '../../domain/repositories/keywords_repository.dart';

export '../../data/services/search_performance_sync_service.dart';
export '../../domain/entities/cannibalization_finding.dart';
export '../../domain/entities/keyword.dart';
export '../../domain/entities/keyword_group.dart';
export '../../domain/entities/rank_observation.dart';
export '../../domain/entities/ranking_alert.dart';
export '../../domain/models/alert_settings.dart';
export '../../domain/repositories/keywords_repository.dart';

final keywordsRepositoryProvider = Provider<KeywordsRepository>((ref) {
  return KeywordsRepositoryImpl();
});

final keywordGroupsDatasourceProvider = Provider<LocalKeywordGroupsDatasource>((
  ref,
) {
  return LocalKeywordGroupsDatasource();
});

final rankingAlertsDatasourceProvider = Provider<LocalRankingAlertsDatasource>((
  ref,
) {
  return LocalRankingAlertsDatasource();
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

      // Invalidate keyword list, groups, alerts, and observation views for instant UI updates
      ref.invalidate(keywordsFamilyProvider(websiteId));
      ref.invalidate(keywordGroupsFamilyProvider(websiteId));
      ref.invalidate(rankingAlertsFamilyProvider(websiteId));
      ref.invalidate(cannibalizationFindingsFamilyProvider(websiteId));
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

  Future<void> loadKeywords({
    String? searchEngine,
    int? groupId,
    bool onlyUngrouped = false,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(keywordsRepositoryProvider);
      return repo.getKeywordsByWebsite(
        websiteId,
        searchEngine: searchEngine,
        groupId: groupId,
        onlyUngrouped: onlyUngrouped,
      );
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
    int? groupId,
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
      groupId: groupId,
      isActive: isActive,
      createdAt: now,
    );
    final created = await repo.addKeyword(kw);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
    return created;
  }

  Future<void> updateKeyword(Keyword keyword) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.updateKeyword(keyword);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
  }

  Future<void> moveKeywordGroup(int keywordId, int? newGroupId) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.updateKeywordGroup(keywordId, newGroupId);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
  }

  Future<void> assignKeywordsToGroup(
    List<int> keywordIds,
    int? newGroupId,
  ) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.assignKeywordsToGroup(keywordIds, newGroupId);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
  }

  Future<void> toggleActive(int keywordId, bool isActive) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.toggleActiveStatus(keywordId, isActive);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
  }

  Future<void> deleteKeyword(int id) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.deleteKeyword(id);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
    ref.invalidate(rankingAlertsFamilyProvider(websiteId));
    ref.invalidate(cannibalizationFindingsFamilyProvider(websiteId));
  }

  Future<void> bulkDeleteKeywords(List<int> ids) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.bulkDeleteKeywords(ids);
    await loadKeywords();
    ref.invalidate(keywordGroupsFamilyProvider(websiteId));
    ref.invalidate(rankingAlertsFamilyProvider(websiteId));
    ref.invalidate(cannibalizationFindingsFamilyProvider(websiteId));
  }

  Future<RankObservation> recordObservation(RankObservation observation) async {
    final repo = ref.read(keywordsRepositoryProvider);
    final saved = await repo.recordObservation(observation);
    await loadKeywords();
    ref.invalidate(keywordObservationsFamilyProvider(observation.keywordId));
    ref.invalidate(cannibalizationAlertsFamilyProvider(websiteId));
    ref.invalidate(cannibalizationFindingsFamilyProvider(websiteId));
    ref.invalidate(rankingAlertsFamilyProvider(websiteId));
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

// --- Keyword Groups Notifier & Providers ---

class KeywordGroupsNotifier extends AsyncNotifier<List<KeywordGroup>> {
  final int websiteId;

  KeywordGroupsNotifier(this.websiteId);

  @override
  Future<List<KeywordGroup>> build() async {
    final ds = ref.watch(keywordGroupsDatasourceProvider);
    return ds.getGroupsByWebsite(websiteId);
  }

  Future<void> loadGroups() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(keywordGroupsDatasourceProvider);
      return ds.getGroupsByWebsite(websiteId);
    });
  }

  Future<KeywordGroup> createGroup({
    required String name,
    String? colorHex,
    String? description,
  }) async {
    final ds = ref.read(keywordGroupsDatasourceProvider);
    final now = DateTime.now();
    final group = KeywordGroup(
      websiteId: websiteId,
      name: name.trim(),
      colorHex: colorHex ?? '#2563EB',
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final created = await ds.createGroup(group);
    await loadGroups();
    return created;
  }

  Future<void> updateGroup(KeywordGroup group) async {
    final ds = ref.read(keywordGroupsDatasourceProvider);
    await ds.updateGroup(group.copyWith(updatedAt: DateTime.now()));
    await loadGroups();
    ref.invalidate(keywordsFamilyProvider(websiteId));
  }

  Future<void> deleteGroup(int id) async {
    final ds = ref.read(keywordGroupsDatasourceProvider);
    await ds.deleteGroup(id);
    await loadGroups();
    ref.invalidate(keywordsFamilyProvider(websiteId));
  }
}

final keywordGroupsFamilyProvider =
    AsyncNotifierProvider.family<KeywordGroupsNotifier, List<KeywordGroup>, int>(
      (websiteId) => KeywordGroupsNotifier(websiteId),
    );

final ungroupedSummaryFamilyProvider =
    FutureProvider.family<KeywordGroup, int>((ref, websiteId) async {
      final ds = ref.watch(keywordGroupsDatasourceProvider);
      return await ds.getUngroupedSummary(websiteId);
    });

// --- Ranking Alerts Notifier & Providers ---

class RankingAlertsNotifier extends AsyncNotifier<List<RankingAlert>> {
  final int websiteId;

  RankingAlertsNotifier(this.websiteId);

  @override
  Future<List<RankingAlert>> build() async {
    final ds = ref.watch(rankingAlertsDatasourceProvider);
    return ds.getAlertsByWebsite(websiteId);
  }

  Future<void> loadAlerts({
    bool? unreadOnly,
    String? alertType,
    String? severity,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(rankingAlertsDatasourceProvider);
      return ds.getAlertsByWebsite(
        websiteId,
        unreadOnly: unreadOnly,
        alertType: alertType,
        severity: severity,
      );
    });
  }

  Future<void> markAsRead(int alertId) async {
    final ds = ref.read(rankingAlertsDatasourceProvider);
    await ds.markAsRead(alertId);
    await loadAlerts();
    ref.invalidate(unreadAlertsCountProvider(websiteId));
  }

  Future<void> markAllAsRead() async {
    final ds = ref.read(rankingAlertsDatasourceProvider);
    await ds.markAllAsRead(websiteId);
    await loadAlerts();
    ref.invalidate(unreadAlertsCountProvider(websiteId));
  }

  Future<void> deleteAlert(int alertId) async {
    final ds = ref.read(rankingAlertsDatasourceProvider);
    await ds.deleteAlert(alertId);
    await loadAlerts();
    ref.invalidate(unreadAlertsCountProvider(websiteId));
  }

  Future<void> clearAll() async {
    final ds = ref.read(rankingAlertsDatasourceProvider);
    await ds.clearAlerts(websiteId);
    await loadAlerts();
    ref.invalidate(unreadAlertsCountProvider(websiteId));
  }
}

final rankingAlertsFamilyProvider =
    AsyncNotifierProvider.family<RankingAlertsNotifier, List<RankingAlert>, int>(
      (websiteId) => RankingAlertsNotifier(websiteId),
    );

final unreadAlertsCountProvider =
    FutureProvider.family<int, int>((ref, websiteId) async {
      final ds = ref.watch(rankingAlertsDatasourceProvider);
      return ds.getUnreadCount(websiteId);
    });

// --- Alert Settings Notifier & Provider ---

class AlertSettingsNotifier extends AsyncNotifier<AlertSettings> {
  @override
  Future<AlertSettings> build() async {
    final storage = SecureStorageService();
    return storage.getAlertSettings();
  }

  Future<void> updateSettings(AlertSettings settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = SecureStorageService();
      await storage.saveAlertSettings(settings);
      return settings;
    });
  }
}

final alertSettingsProvider =
    AsyncNotifierProvider<AlertSettingsNotifier, AlertSettings>(
      () => AlertSettingsNotifier(),
    );

// --- Cannibalization Diagnostics Provider ---

final cannibalizationFindingsFamilyProvider =
    FutureProvider.family<List<CannibalizationFinding>, int>((
      ref,
      websiteId,
    ) async {
      final keywords =
          await ref.watch(keywordsFamilyProvider(websiteId).future);
      final repo = ref.watch(keywordsRepositoryProvider);

      final Map<int, List<RankObservation>> obsMap = {};
      for (final kw in keywords) {
        if (kw.id == null) continue;
        final obs = await repo.getObservationsForKeyword(kw.id!);
        obsMap[kw.id!] = obs;
      }

      return const KeywordAnalysisService().detectCannibalization(
        keywords: keywords,
        observationsByKeywordId: obsMap,
      );
    });
