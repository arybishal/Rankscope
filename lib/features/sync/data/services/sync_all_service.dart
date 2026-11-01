import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../keywords/data/services/search_performance_sync_service.dart';
import '../../../websites/data/datasources/local_websites_datasource.dart';
import '../../../websites/domain/entities/website.dart';
import '../datasources/sync_history_datasource.dart';
import '../../domain/models/sync_models.dart';

/// Exception thrown when a sync operation is initiated while another is already running.
class SyncInProgressException implements Exception {
  final String message;
  const SyncInProgressException([this.message = 'A sync operation is already in progress.']);

  @override
  String toString() => message;
}

/// Service that orchestrates multi-website and multi-engine synchronization
/// with concurrency protection, progress reporting, exponential retry, and persistence.
class SyncAllService {
  final LocalWebsitesDatasource _websitesDatasource;
  final SearchPerformanceSyncService _searchSyncService;
  final SecureStorageService _secureStorage;
  final SyncHistoryDatasource _historyDatasource;

  static final SyncAllService instance = SyncAllService();

  SyncAllService({
    LocalWebsitesDatasource? websitesDatasource,
    SearchPerformanceSyncService? searchSyncService,
    SecureStorageService? secureStorage,
    SyncHistoryDatasource? historyDatasource,
  }) : _websitesDatasource = websitesDatasource ?? LocalWebsitesDatasource(),
       _searchSyncService = searchSyncService ?? SearchPerformanceSyncService(),
       _secureStorage = secureStorage ?? SecureStorageService(),
       _historyDatasource = historyDatasource ?? SyncHistoryDatasource();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final ValueNotifier<SyncProgress> progressNotifier = ValueNotifier<SyncProgress>(
    const SyncProgress(
      currentStep: 0,
      totalSteps: 0,
      currentWebsiteDomain: '',
      currentOperation: 'Idle',
    ),
  );

  /// Executes synchronization for all active (non-competitor) websites across
  /// all connected search engines (Google, Bing, Yandex).
  Future<SyncSummary> syncAllWebsites({
    bool isBackground = false,
    int? customDateWindowDays,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    if (_isSyncing) {
      throw const SyncInProgressException(
        'Synchronization is already running. Duplicate or overlapping sync prevented.',
      );
    }

    _isSyncing = true;
    final startedAt = DateTime.now();

    try {
      await AppLogger.instance.info(
        'SyncAllService',
        'sync_all_started',
        'Initiating Sync All (isBackground: $isBackground)',
      );

      // 1. Fetch all primary active websites
      final List<Website> websites =
          await _websitesDatasource.getWebsites(isCompetitor: false);

      if (websites.isEmpty) {
        final summary = SyncSummary(
          startedAt: startedAt,
          completedAt: DateTime.now(),
          status: 'success',
          totalWebsites: 0,
          successfulWebsites: 0,
          failedWebsites: 0,
          totalQueriesSynced: 0,
          isBackground: isBackground,
          websiteDetails: const [],
          overallMessage: 'No active websites to synchronize.',
        );

        await _secureStorage.saveLastSyncSummary(summary);
        _updateProgress(
          step: 0,
          total: 0,
          domain: '',
          op: 'No websites found',
          isDone: true,
          summary: summary,
          callback: onProgress,
        );
        return summary;
      }

      // 2. Discover configured integrations up front
      final googleConfigured = await _searchSyncService.isGoogleConfigured();
      final bingConfigured = await _searchSyncService.isBingConfigured();
      final yandexConfigured = await _searchSyncService.isYandexConfigured();

      final totalWebsites = websites.length;
      final List<WebsiteSyncDetail> websiteResults = [];
      int successfulCount = 0;
      int failedCount = 0;
      int totalQueries = 0;

      for (int i = 0; i < totalWebsites; i++) {
        final site = websites[i];
        final siteIndex = i + 1;

        _updateProgress(
          step: siteIndex,
          total: totalWebsites,
          domain: site.domain,
          op: 'Syncing ${site.domain} ($siteIndex of $totalWebsites)',
          isDone: false,
          callback: onProgress,
        );

        WebsiteSyncDetail siteDetail;
        try {
          // Attempt sync with exponential backoff on transient network/server failures
          final result = await _executeWithRetry(
            () => _searchSyncService.syncPerformanceForWebsite(
              websiteId: site.id!,
              domain: site.domain,
              gscPropertyId: site.gscPropertyId,
              bingSiteUrl: site.bingSiteUrl,
              yandexHostId: site.yandexHostId,
              dateWindowDays: customDateWindowDays,
            ),
            operationName: 'Sync ${site.domain}',
          );

          final List<EngineSyncDetail> engines = [
            EngineSyncDetail(
              engine: 'Google',
              isConnected: googleConfigured,
              isSuccess: googleConfigured &&
                  !(result.googleStatusMessage?.toLowerCase().contains('failed') ?? false) &&
                  !(result.googleStatusMessage?.toLowerCase().contains('error') ?? false),
              queriesCount: result.googleQueriesAvailable,
              message: result.googleStatusMessage,
            ),
            EngineSyncDetail(
              engine: 'Bing',
              isConnected: bingConfigured,
              isSuccess: bingConfigured &&
                  !(result.bingStatusMessage?.toLowerCase().contains('failed') ?? false) &&
                  !(result.bingStatusMessage?.toLowerCase().contains('error') ?? false),
              queriesCount: result.bingQueriesAvailable,
              message: result.bingStatusMessage,
            ),
            EngineSyncDetail(
              engine: 'Yandex',
              isConnected: yandexConfigured,
              isSuccess: yandexConfigured &&
                  !(result.yandexStatusMessage?.toLowerCase().contains('failed') ?? false) &&
                  !(result.yandexStatusMessage?.toLowerCase().contains('error') ?? false),
              queriesCount: result.yandexQueriesAvailable,
              message: result.yandexStatusMessage,
            ),
          ];

          final siteQueries = result.googleQueriesAvailable +
              result.bingQueriesAvailable +
              result.yandexQueriesAvailable;
          totalQueries += siteQueries;

          siteDetail = WebsiteSyncDetail(
            websiteId: site.id!,
            domain: site.domain,
            label: site.label,
            isSuccess: true,
            totalKeywords: result.totalKeywords,
            matchedKeywords: result.matchedKeywords,
            engineDetails: engines,
          );
          successfulCount++;

          // Record individual engine sync history in SQLite
          for (final eng in engines) {
            if (eng.isConnected) {
              await _historyDatasource.insertRecord(
                SyncHistoryRecord(
                  websiteId: site.id,
                  websiteDomain: site.domain,
                  searchEngine: eng.engine,
                  startedAt: startedAt,
                  completedAt: DateTime.now(),
                  status: eng.isSuccess ? 'success' : 'failed',
                  recordsRetrieved: eng.queriesCount,
                  matchedKeywords: result.matchedKeywords,
                  errorDetails: eng.isSuccess ? null : (eng.error ?? eng.message),
                  triggerType: isBackground ? 'auto' : 'manual',
                  createdAt: DateTime.now(),
                ),
              );
            }
          }
        } catch (e) {
          failedCount++;
          await AppLogger.instance.error(
            'SyncAllService',
            'site_sync_error',
            'Error synchronizing site ${site.domain}: $e',
          );

          // Record failed audit record in SQLite
          await _historyDatasource.insertRecord(
            SyncHistoryRecord(
              websiteId: site.id,
              websiteDomain: site.domain,
              searchEngine: 'All',
              startedAt: startedAt,
              completedAt: DateTime.now(),
              status: 'failed',
              recordsRetrieved: 0,
              matchedKeywords: 0,
              errorDetails: e.toString(),
              triggerType: isBackground ? 'auto' : 'manual',
              createdAt: DateTime.now(),
            ),
          );

          siteDetail = WebsiteSyncDetail(
            websiteId: site.id ?? 0,
            domain: site.domain,
            label: site.label,
            isSuccess: false,
            errorMessage: e.toString(),
            engineDetails: [
              EngineSyncDetail(
                engine: 'Google',
                isConnected: googleConfigured,
                isSuccess: false,
                error: googleConfigured ? e.toString() : 'Not configured',
              ),
              EngineSyncDetail(
                engine: 'Bing',
                isConnected: bingConfigured,
                isSuccess: false,
                error: bingConfigured ? e.toString() : 'Not configured',
              ),
              EngineSyncDetail(
                engine: 'Yandex',
                isConnected: yandexConfigured,
                isSuccess: false,
                error: yandexConfigured ? e.toString() : 'Not configured',
              ),
            ],
          );
        }

        websiteResults.add(siteDetail);
      }

      final completedAt = DateTime.now();
      final status = failedCount == 0
          ? 'success'
          : (successfulCount > 0 ? 'partial_success' : 'failed');

      final overallMessage =
          'Sync All finished: $successfulCount/$totalWebsites websites successful. $totalQueries total queries synced.';

      final summary = SyncSummary(
        startedAt: startedAt,
        completedAt: completedAt,
        status: status,
        totalWebsites: totalWebsites,
        successfulWebsites: successfulCount,
        failedWebsites: failedCount,
        totalQueriesSynced: totalQueries,
        isBackground: isBackground,
        websiteDetails: websiteResults,
        overallMessage: overallMessage,
      );

      // Persist summary safely
      await _secureStorage.saveLastSyncSummary(summary);

      await AppLogger.instance.info(
        'SyncAllService',
        'sync_all_completed',
        overallMessage,
      );

      _updateProgress(
        step: totalWebsites,
        total: totalWebsites,
        domain: '',
        op: 'Completed',
        isDone: true,
        summary: summary,
        callback: onProgress,
      );

      return summary;
    } finally {
      _isSyncing = false;
    }
  }

  void _updateProgress({
    required int step,
    required int total,
    required String domain,
    required String op,
    bool isDone = false,
    SyncSummary? summary,
    void Function(SyncProgress progress)? callback,
  }) {
    final progress = SyncProgress(
      currentStep: step,
      totalSteps: total,
      currentWebsiteDomain: domain,
      currentOperation: op,
      isCompleted: isDone,
      summary: summary,
    );
    progressNotifier.value = progress;
    callback?.call(progress);
  }

  /// Executes an operation with exponential backoff retry for transient network issues.
  Future<T> _executeWithRetry<T>(
    Future<T> Function() action, {
    required String operationName,
    int maxRetries = 2,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      attempts++;
      try {
        return await action();
      } catch (e) {
        final isNetworkError = e is SocketException ||
            e is TimeoutException ||
            e.toString().toLowerCase().contains('connection') ||
            e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('handshake') ||
            e.toString().toLowerCase().contains('timeout');

        // Do not retry non-network errors (e.g. invalid auth token)
        if (!isNetworkError || attempts > maxRetries) {
          rethrow;
        }

        await AppLogger.instance.warning(
          'SyncAllService',
          'transient_retry',
          '$operationName failed (attempt $attempts of ${maxRetries + 1}). Retrying in ${currentDelay.inSeconds}s... Error: $e',
        );

        await Future.delayed(currentDelay);
        currentDelay *= 2; // Exponential backoff: 2s, 4s...
      }
    }
  }
}
