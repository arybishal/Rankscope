import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/keywords_repository_impl.dart';
import '../../domain/repositories/keywords_repository.dart';

export '../../domain/entities/keyword.dart';
export '../../domain/entities/rank_observation.dart';
export '../../domain/repositories/keywords_repository.dart';

final keywordsRepositoryProvider = Provider<KeywordsRepository>((ref) {
  return KeywordsRepositoryImpl();
});

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
