import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/manual_rank_repository_impl.dart';
import '../../domain/entities/manual_rank_record.dart';
import '../../domain/repositories/manual_rank_repository.dart';

final manualRankRepositoryProvider = Provider<ManualRankRepository>((ref) {
  return ManualRankRepositoryImpl();
});

class ManualRankNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> recordRank({
    required int keywordId,
    required int websiteId,
    required int position,
    String? rankingUrl,
    String searchEngine = 'Google',
    String locationCountry = 'GLOBAL',
    String? locationCity,
    int serpFeaturesMask = 0,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(manualRankRepositoryProvider);
      final record = ManualRankRecord(
        keywordId: keywordId,
        websiteId: websiteId,
        position: position,
        rankingUrl: rankingUrl,
        searchEngine: searchEngine,
        locationCountry: locationCountry,
        locationCity: locationCity,
        serpFeaturesMask: serpFeaturesMask,
        notes: notes,
        recordedAt: DateTime.now(),
      );

      await repo.recordRank(record);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final manualRankNotifierProvider =
    AsyncNotifierProvider<ManualRankNotifier, void>(ManualRankNotifier.new);

final keywordHistoryProvider =
    FutureProvider.family<List<ManualRankRecord>, int>((ref, keywordId) async {
      final repo = ref.watch(manualRankRepositoryProvider);
      return await repo.getHistoryForKeyword(keywordId);
    });
