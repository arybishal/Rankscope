import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../data/services/sync_all_service.dart';

/// Unique identifiers for background sync tasks.
const String kDailySyncTaskKey = 'com.rankscope.app.dailySyncTask';
const String kDailySyncUniqueName = 'rankscope_daily_sync';
const String kOneOffSyncTaskKey = 'com.rankscope.app.oneOffSyncTask';

/// Top-level callback dispatcher for Android WorkManager.
/// Must be annotated with `@pragma('vm:entry-point')` so Flutter's AOT
/// compiler does not tree-shake it in release mode.
@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await AppLogger.instance.info(
        'WorkManager',
        'background_sync_triggered',
        'Executing background sync task: $taskName',
      );

      // Verify and initialize SQLite database in background isolate
      await AppDatabase.instance.database;

      // Execute Sync All
      final summary = await SyncAllService.instance.syncAllWebsites(
        isBackground: true,
      );

      await AppLogger.instance.info(
        'WorkManager',
        'background_sync_finished',
        'Task $taskName completed with status: ${summary.status}',
      );

      return true;
    } catch (e) {
      await AppLogger.instance.error(
        'WorkManager',
        'background_sync_exception',
        'Background sync task failed: $e',
      );
      // Return false to allow WorkManager exponential backoff retry on temporary failure
      return false;
    }
  });
}

/// Helper service to initialize, schedule, cancel, and inspect daily WorkManager tasks.
class SyncScheduler {
  final SecureStorageService _secureStorage;

  static final SyncScheduler instance = SyncScheduler();

  SyncScheduler({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  /// Initializes the WorkManager plugin with the entry-point dispatcher.
  Future<void> initialize() async {
    // Only Android and iOS support WorkManager background tasks
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Workmanager().initialize(
        syncCallbackDispatcher,
      );
    } catch (e) {
      await AppLogger.instance.warning(
        'SyncScheduler',
        'workmanager_init_warning',
        'WorkManager init: $e',
      );
    }
  }

  /// Calculates the next local scheduled sync time.
  DateTime computeNextScheduleTime(int hour, int minute, [DateTime? from]) {
    final now = from ?? DateTime.now();
    DateTime scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledToday.isAfter(now)) {
      return scheduledToday;
    } else {
      return scheduledToday.add(const Duration(days: 1));
    }
  }

  /// Schedules or updates the periodic daily sync in WorkManager.
  /// If autoSyncEnabled is false, cancels existing scheduled work.
  Future<DateTime?> scheduleDailySync() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    final isEnabled = await _secureStorage.getAutoSyncEnabled();
    if (!isEnabled) {
      await cancelDailySync();
      return null;
    }

    final hour = await _secureStorage.getAutoSyncHour();
    final minute = await _secureStorage.getAutoSyncMinute();
    final nextTime = computeNextScheduleTime(hour, minute);
    final initialDelay = nextTime.difference(DateTime.now());

    // WorkManager minimum delay is 0, duration clamp ensures no negative values
    final safeDelay = initialDelay.isNegative ? Duration.zero : initialDelay;

    try {
      await Workmanager().registerPeriodicTask(
        kDailySyncUniqueName,
        kDailySyncTaskKey,
        frequency: const Duration(hours: 24),
        initialDelay: safeDelay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );

      await AppLogger.instance.info(
        'SyncScheduler',
        'daily_sync_scheduled',
        'Registered 24h periodic sync. First run in ${safeDelay.inHours}h ${safeDelay.inMinutes % 60}m at ${nextTime.toLocal()}',
      );

      return nextTime;
    } catch (e) {
      await AppLogger.instance.error(
        'SyncScheduler',
        'schedule_error',
        'Failed to register periodic task: $e',
      );
      return null;
    }
  }

  /// Cancels the scheduled daily sync task.
  Future<void> cancelDailySync() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Workmanager().cancelByUniqueName(kDailySyncUniqueName);
      await AppLogger.instance.info(
        'SyncScheduler',
        'daily_sync_cancelled',
        'Cancelled periodic daily sync task.',
      );
    } catch (e) {
      await AppLogger.instance.warning(
        'SyncScheduler',
        'cancel_error',
        'Could not cancel periodic task: $e',
      );
    }
  }
}
