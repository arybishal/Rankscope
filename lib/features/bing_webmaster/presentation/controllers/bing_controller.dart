import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../data/datasources/local_bing_datasource.dart';
import '../../data/datasources/remote_bing_datasource.dart';
import '../../data/repositories/bing_repository_impl.dart';
import '../../domain/entities/bing_metric.dart';
import '../../domain/repositories/bing_repository.dart';

export '../../domain/entities/bing_metric.dart';
export '../../domain/repositories/bing_repository.dart';

final remoteBingDatasourceProvider = Provider<RemoteBingDatasource>((ref) {
  return RemoteBingDatasource();
});

final localBingDatasourceProvider = Provider<LocalBingDatasource>((ref) {
  return LocalBingDatasource();
});

final bingRepositoryProvider = Provider<BingRepository>((ref) {
  return BingRepositoryImpl(
    localDatasource: ref.watch(localBingDatasourceProvider),
    remoteDatasource: ref.watch(remoteBingDatasourceProvider),
  );
});

final bingMetricsFutureProvider = FutureProvider.family<List<BingMetric>, int>((
  ref,
  websiteId,
) async {
  final repo = ref.watch(bingRepositoryProvider);
  return await repo.getMetrics(websiteId, limit: 100);
});

class BingSyncState {
  final bool isSyncing;
  final String? errorMessage;
  final int? lastSyncedCount;

  const BingSyncState({
    this.isSyncing = false,
    this.errorMessage,
    this.lastSyncedCount,
  });

  BingSyncState copyWith({
    bool? isSyncing,
    String? errorMessage,
    int? lastSyncedCount,
  }) {
    return BingSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
    );
  }
}

class BingSyncNotifier extends Notifier<BingSyncState> {
  @override
  BingSyncState build() => const BingSyncState();

  Future<int?> syncWebsite(int websiteId, String domain) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repo = ref.read(bingRepositoryProvider);
      final count = await repo.syncMetricsFromApi(
        websiteId: websiteId,
        siteUrl: domain,
      );

      state = state.copyWith(
        isSyncing: false,
        lastSyncedCount: count,
        errorMessage: null,
      );

      // Invalidate cached metrics so UI updates immediately
      ref.invalidate(bingMetricsFutureProvider(websiteId));
      return count;
    } on Failure catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'An unexpected error occurred: $e',
      );
      return null;
    }
  }

  Future<List<String>?> testConnection() async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repo = ref.read(bingRepositoryProvider);
      final sites = await repo.getVerifiedSites();
      state = state.copyWith(isSyncing: false, errorMessage: null);
      return sites;
    } on Failure catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Connection test failed: $e',
      );
      return null;
    }
  }
}

final bingSyncNotifierProvider =
    NotifierProvider<BingSyncNotifier, BingSyncState>(() {
      return BingSyncNotifier();
    });
