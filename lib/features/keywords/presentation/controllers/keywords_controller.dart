import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/keywords_repository_impl.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/repositories/keywords_repository.dart';

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

  Future<void> loadKeywords() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(keywordsRepositoryProvider);
      return repo.getKeywordsByWebsite(websiteId);
    });
  }

  Future<Keyword?> addKeyword({
    required String keywordText,
    String? targetUrl,
    String targetCountry = 'GLOBAL',
    String? targetCity,
    List<String> tags = const [],
  }) async {
    final repo = ref.read(keywordsRepositoryProvider);
    final kw = Keyword(
      websiteId: websiteId,
      keywordText: keywordText.trim(),
      targetUrl: targetUrl?.trim(),
      targetCountry: targetCountry.trim().toUpperCase(),
      targetCity: targetCity?.trim(),
      tags: tags,
      createdAt: DateTime.now(),
    );
    final created = await repo.addKeyword(kw);
    await loadKeywords();
    return created;
  }

  Future<void> deleteKeyword(int id) async {
    final repo = ref.read(keywordsRepositoryProvider);
    await repo.deleteKeyword(id);
    await loadKeywords();
  }
}

final keywordsFamilyProvider = AsyncNotifierProvider.family<KeywordsNotifier, List<Keyword>, int>(
  (websiteId) => KeywordsNotifier(websiteId),
);
