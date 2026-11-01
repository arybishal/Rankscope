import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../../keywords/presentation/controllers/keywords_controller.dart';
import '../../../websites/data/datasources/local_websites_datasource.dart';
import '../../../websites/presentation/controllers/websites_controller.dart';
import '../../background/sync_workmanager.dart';
import '../../data/services/sync_all_service.dart';
import '../../domain/models/sync_models.dart';

/// Full state model for the Sync Dashboard and preferences.
class SyncDashboardState {
  final bool isLoading;
  final bool isSyncing;
  final SyncProgress progress;
  final bool autoSyncEnabled;
  final int autoSyncHour;
  final int autoSyncMinute;
  final int dateWindowDays;
  final DateTime? nextScheduledSync;
  final DateTime? lastSyncTime;
  final SyncSummary? lastSummary;
  final int totalWebsitesCount;
  final String? errorMessage;

  const SyncDashboardState({
    this.isLoading = true,
    this.isSyncing = false,
    this.progress = const SyncProgress(
      currentStep: 0,
      totalSteps: 0,
      currentWebsiteDomain: '',
      currentOperation: 'Idle',
    ),
    this.autoSyncEnabled = true,
    this.autoSyncHour = 8,
    this.autoSyncMinute = 0,
    this.dateWindowDays = 30,
    this.nextScheduledSync,
    this.lastSyncTime,
    this.lastSummary,
    this.totalWebsitesCount = 0,
    this.errorMessage,
  });

  SyncDashboardState copyWith({
    bool? isLoading,
    bool? isSyncing,
    SyncProgress? progress,
    bool? autoSyncEnabled,
    int? autoSyncHour,
    int? autoSyncMinute,
    int? dateWindowDays,
    DateTime? nextScheduledSync,
    DateTime? lastSyncTime,
    SyncSummary? lastSummary,
    int? totalWebsitesCount,
    String? errorMessage,
  }) {
    return SyncDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      progress: progress ?? this.progress,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      autoSyncHour: autoSyncHour ?? this.autoSyncHour,
      autoSyncMinute: autoSyncMinute ?? this.autoSyncMinute,
      dateWindowDays: dateWindowDays ?? this.dateWindowDays,
      nextScheduledSync: nextScheduledSync ?? this.nextScheduledSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSummary: lastSummary ?? this.lastSummary,
      totalWebsitesCount: totalWebsitesCount ?? this.totalWebsitesCount,
      errorMessage: errorMessage,
    );
  }
}

/// Riverpod Notifier managing sync operations, settings, and dashboard state.
class SyncNotifier extends Notifier<SyncDashboardState> {
  late final SyncAllService _syncAllService;
  late final SyncScheduler _scheduler;
  late final SecureStorageService _secureStorage;
  late final LocalWebsitesDatasource _websitesDatasource;
  bool _mounted = true;

  @override
  SyncDashboardState build() {
    _syncAllService = SyncAllService.instance;
    _scheduler = SyncScheduler.instance;
    _secureStorage = SecureStorageService();
    _websitesDatasource = LocalWebsitesDatasource();
    _mounted = true;

    ref.onDispose(() {
      _mounted = false;
    });

    // Schedule state loading asynchronously upon provider creation
    Future.microtask(() {
      if (_mounted) refreshState();
    });

    return const SyncDashboardState();
  }

  /// Reloads scheduling preferences, last sync summary, and site counts from storage.
  Future<void> refreshState() async {
    try {
      final isEnabled = await _secureStorage.getAutoSyncEnabled();
      final hour = await _secureStorage.getAutoSyncHour();
      final minute = await _secureStorage.getAutoSyncMinute();
      final window = await _secureStorage.getAutoSyncDateWindowDays();
      final lastSummary = await _secureStorage.getLastSyncSummary();
      final lastEpoch = await _secureStorage.getLastSyncEpochMs();

      DateTime? lastSync;
      if (lastSummary != null) {
        lastSync = lastSummary.completedAt;
      } else if (lastEpoch != null) {
        lastSync = DateTime.fromMillisecondsSinceEpoch(lastEpoch);
      }

      final nextScheduled = isEnabled
          ? _scheduler.computeNextScheduleTime(hour, minute)
          : null;

      final sites = await _websitesDatasource.getWebsites(isCompetitor: false);

      if (!_mounted) return;

      state = state.copyWith(
        isLoading: false,
        isSyncing: _syncAllService.isSyncing,
        autoSyncEnabled: isEnabled,
        autoSyncHour: hour,
        autoSyncMinute: minute,
        dateWindowDays: window,
        nextScheduledSync: nextScheduled,
        lastSyncTime: lastSync,
        lastSummary: lastSummary,
        totalWebsitesCount: sites.length,
        errorMessage: null,
      );
    } catch (e) {
      if (!_mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Triggers a Manual Sync All across all active websites and connected engines.
  Future<SyncSummary?> syncAllNow() async {
    if (state.isSyncing || _syncAllService.isSyncing) return null;

    state = state.copyWith(
      isSyncing: true,
      errorMessage: null,
    );

    try {
      final summary = await _syncAllService.syncAllWebsites(
        isBackground: false,
        customDateWindowDays: state.dateWindowDays,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );

      // Invalidate relevant Riverpod providers so the UI immediately reflects new data
      ref.invalidate(websitesProvider);
      final activeId = ref.read(selectedWebsiteIdProvider);
      if (activeId != null) {
        ref.invalidate(keywordsFamilyProvider(activeId));
      }

      state = state.copyWith(
        isSyncing: false,
        lastSummary: summary,
        lastSyncTime: summary.completedAt,
        errorMessage: null,
      );

      return summary;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Toggles automatic daily background sync on or off.
  Future<void> toggleAutoSync(bool enabled) async {
    await _secureStorage.setAutoSyncEnabled(enabled);
    if (enabled) {
      final nextTime = await _scheduler.scheduleDailySync();
      state = state.copyWith(
        autoSyncEnabled: true,
        nextScheduledSync: nextTime,
      );
    } else {
      await _scheduler.cancelDailySync();
      state = state.copyWith(
        autoSyncEnabled: false,
        nextScheduledSync: null,
      );
    }
  }

  /// Updates the scheduled daily sync time and updates WorkManager.
  Future<void> updateScheduleTime(int hour, int minute) async {
    await _secureStorage.setAutoSyncHour(hour);
    await _secureStorage.setAutoSyncMinute(minute);

    DateTime? nextTime;
    if (state.autoSyncEnabled) {
      nextTime = await _scheduler.scheduleDailySync();
    } else {
      nextTime = _scheduler.computeNextScheduleTime(hour, minute);
    }

    state = state.copyWith(
      autoSyncHour: hour,
      autoSyncMinute: minute,
      nextScheduledSync: state.autoSyncEnabled ? nextTime : null,
    );
  }

  /// Updates the history date window (e.g. 7, 14, 30, 60, 90 days).
  Future<void> updateDateWindowDays(int days) async {
    await _secureStorage.setAutoSyncDateWindowDays(days);
    state = state.copyWith(dateWindowDays: days);
  }
}

final syncControllerProvider =
    NotifierProvider<SyncNotifier, SyncDashboardState>(
  SyncNotifier.new,
);
