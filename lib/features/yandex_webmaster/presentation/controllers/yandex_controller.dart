import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../data/repositories/yandex_repository_impl.dart';
import '../../domain/entities/yandex_host.dart';
import '../../domain/entities/yandex_metric.dart';
import '../../domain/repositories/yandex_repository.dart';

final yandexRepositoryProvider = Provider<YandexRepository>((ref) {
  return YandexRepositoryImpl();
});

final yandexConfiguredProvider = FutureProvider<bool>((ref) async {
  final storage = SecureStorageService();
  final token = await storage.getYandexOAuthToken();
  return token != null && token.trim().isNotEmpty;
});

final yandexHostsFutureProvider = FutureProvider<List<YandexHost>>((ref) async {
  final repo = ref.watch(yandexRepositoryProvider);
  return await repo.getUserHosts();
});

final yandexMetricsFutureProvider =
    FutureProvider.family<List<YandexMetric>, int>((ref, websiteId) async {
  final repo = ref.watch(yandexRepositoryProvider);
  return await repo.getMetrics(websiteId, limit: 100);
});

final yandexAggregatesFutureProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, websiteId) async {
  final repo = ref.watch(yandexRepositoryProvider);
  return await repo.getAggregates(websiteId);
});

class YandexSyncState {
  final bool isSyncing;
  final String? errorMessage;
  final List<YandexHost>? verifiedHosts;

  const YandexSyncState({
    this.isSyncing = false,
    this.errorMessage,
    this.verifiedHosts,
  });

  YandexSyncState copyWith({
    bool? isSyncing,
    String? errorMessage,
    List<YandexHost>? verifiedHosts,
  }) {
    return YandexSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage,
      verifiedHosts: verifiedHosts ?? this.verifiedHosts,
    );
  }
}

class YandexSyncNotifier extends Notifier<YandexSyncState> {
  @override
  YandexSyncState build() => const YandexSyncState();

  Future<List<YandexHost>?> testConnection() async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repo = ref.read(yandexRepositoryProvider);
      final hosts = await repo.getUserHosts();
      state = state.copyWith(isSyncing: false, verifiedHosts: hosts);
      ref.invalidate(yandexConfiguredProvider);
      return hosts;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Yandex connection failed: $e',
      );
      return null;
    }
  }

  Future<int?> syncSiteMetrics({
    required int websiteId,
    required String hostId,
  }) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repo = ref.read(yandexRepositoryProvider);
      final count = await repo.syncMetricsFromApi(
        websiteId: websiteId,
        hostId: hostId,
      );
      state = state.copyWith(isSyncing: false);
      ref.invalidate(yandexMetricsFutureProvider(websiteId));
      ref.invalidate(yandexAggregatesFutureProvider(websiteId));
      return count;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Yandex sync failed: $e',
      );
      return null;
    }
  }
}

final yandexSyncNotifierProvider =
    NotifierProvider<YandexSyncNotifier, YandexSyncState>(
  () => YandexSyncNotifier(),
);
