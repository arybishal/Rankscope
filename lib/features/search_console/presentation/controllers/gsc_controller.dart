import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../data/datasources/local_gsc_datasource.dart';
import '../../data/datasources/remote_gsc_datasource.dart';
import '../../data/repositories/gsc_repository_impl.dart';
import '../../domain/entities/gsc_metric.dart';
import '../../domain/repositories/gsc_repository.dart';
import '../../domain/utils/gsc_property_matcher.dart';

export '../../domain/entities/gsc_metric.dart';
export '../../domain/repositories/gsc_repository.dart';
export '../../domain/utils/gsc_property_matcher.dart';
export '../../data/services/google_auth_service.dart';

import '../../data/services/google_auth_service.dart';

final googleSignInAdapterProvider = Provider<GoogleSignInAdapter>((ref) {
  return DefaultGoogleSignInAdapter();
});

final remoteGscDatasourceProvider = Provider<RemoteGscDatasource>((ref) {
  final adapter = ref.watch(googleSignInAdapterProvider);
  return RemoteGscDatasource(
    tokenRefresher: () => adapter.getFreshAccessToken(
      scopes: [GoogleAuthService.searchConsoleReadOnlyScope],
    ),
  );
});

final localGscDatasourceProvider = Provider<LocalGscDatasource>((ref) {
  return LocalGscDatasource();
});

final gscRepositoryProvider = Provider<GscRepository>((ref) {
  return GscRepositoryImpl(
    localDatasource: ref.watch(localGscDatasourceProvider),
    remoteDatasource: ref.watch(remoteGscDatasourceProvider),
  );
});

final gscMetricsFutureProvider = FutureProvider.family<List<GscMetric>, int>((
  ref,
  websiteId,
) async {
  final repo = ref.watch(gscRepositoryProvider);
  return await repo.getMetrics(websiteId, limit: 100);
});

final gscAggregatesFutureProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, websiteId) async {
      final repo = ref.watch(gscRepositoryProvider);
      return await repo.getAggregates(websiteId);
    });

final gscVerifiedSitesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(gscRepositoryProvider);
  return await repo.listVerifiedSites();
});

class GscSyncState {
  final bool isSyncing;
  final String? errorMessage;
  final int? lastSyncedCount;

  const GscSyncState({
    this.isSyncing = false,
    this.errorMessage,
    this.lastSyncedCount,
  });

  GscSyncState copyWith({
    bool? isSyncing,
    String? errorMessage,
    int? lastSyncedCount,
  }) {
    return GscSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: errorMessage,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
    );
  }
}

class GscSyncNotifier extends Notifier<GscSyncState> {
  @override
  GscSyncState build() => const GscSyncState();

  Future<int?> syncWebsite(
    int websiteId,
    String domain, {
    String? gscPropertyId,
    String? country,
    String? device,
    String? searchType,
  }) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final repo = ref.read(gscRepositoryProvider);
      final now = DateTime.now();
      final endDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final startDate30 = now.subtract(const Duration(days: 30));
      final startDate =
          "${startDate30.year}-${startDate30.month.toString().padLeft(2, '0')}-${startDate30.day.toString().padLeft(2, '0')}";

      String targetSite = gscPropertyId ?? GscPropertyMatcher.defaultSiteUrl(domain);

      final count = await repo.syncMetricsFromApi(
        websiteId: websiteId,
        siteUrl: targetSite,
        startDate: startDate,
        endDate: endDate,
        country: country,
        device: device,
        searchType: searchType,
      );

      state = state.copyWith(
        isSyncing: false,
        lastSyncedCount: count,
        errorMessage: null,
      );

      ref.invalidate(gscMetricsFutureProvider(websiteId));
      ref.invalidate(gscAggregatesFutureProvider(websiteId));
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
      final repo = ref.read(gscRepositoryProvider);
      final sites = await repo.listVerifiedSites();
      state = state.copyWith(isSyncing: false, errorMessage: null);
      ref.invalidate(gscVerifiedSitesProvider);
      return sites;
    } on Failure catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Google connection test failed: $e',
      );
      return null;
    }
  }
}

final gscSyncNotifierProvider =
    NotifierProvider<GscSyncNotifier, GscSyncState>(() {
      return GscSyncNotifier();
    });

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService(
    signInAdapter: ref.watch(googleSignInAdapterProvider),
    remoteDatasource: ref.watch(remoteGscDatasourceProvider),
  );
});

class GscConnectionStatusNotifier extends AsyncNotifier<GscConnectionStatus> {
  @override
  Future<GscConnectionStatus> build() async {
    final authService = ref.watch(googleAuthServiceProvider);
    return await authService.checkConnectionStatus(verifyWithApi: false);
  }

  Future<void> refreshStatus({bool verifyWithApi = false}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(googleAuthServiceProvider);
      return await authService.checkConnectionStatus(
        verifyWithApi: verifyWithApi,
      );
    });
  }

  Future<GscConnectionStatus> connectGoogle({
    String? clientId,
    String? serverClientId,
  }) async {
    state = const AsyncValue.data(
      GscConnectionStatus(
        state: GscConnectionState.connecting,
        label: 'Connecting...',
        message: 'Authorizing with Google...',
      ),
    );
    final authService = ref.read(googleAuthServiceProvider);
    final newStatus = await authService.signInAndAuthorize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
    state = AsyncValue.data(newStatus);
    return newStatus;
  }

  Future<GscConnectionStatus> verifyConnection() async {
    state = const AsyncValue.data(
      GscConnectionStatus(
        state: GscConnectionState.connecting,
        label: 'Verifying...',
        message: 'Testing connection to Google Search Console API...',
      ),
    );
    final authService = ref.read(googleAuthServiceProvider);
    final newStatus = await authService.verifySearchConsoleAccess();
    state = AsyncValue.data(newStatus);
    return newStatus;
  }

  Future<void> disconnect() async {
    final authService = ref.read(googleAuthServiceProvider);
    final newStatus = await authService.disconnect();
    state = AsyncValue.data(newStatus);
  }
}

final gscConnectionStatusProvider =
    AsyncNotifierProvider<GscConnectionStatusNotifier, GscConnectionStatus>(() {
      return GscConnectionStatusNotifier();
    });
