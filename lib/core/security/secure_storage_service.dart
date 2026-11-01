import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/sync/domain/models/sync_models.dart';
import '../../features/keywords/domain/models/alert_settings.dart';

/// Secure hardware-backed storage for API keys and OAuth tokens using Android KeyStore.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );

  static const String _keyGscRefreshToken = 'gsc_refresh_token';
  static const String _keyGscAccessToken = 'gsc_access_token';
  static const String _keyGscTokenExpiry = 'gsc_token_expiry';
  static const String _keyGscClientId = 'gsc_client_id';
  static const String _keyGscServerClientId = 'gsc_server_client_id';
  static const String _keyGscUserEmail = 'gsc_user_email';
  static const String _keyGscUserDisplayName = 'gsc_user_display_name';
  static const String _keyGscLastVerified = 'gsc_last_verified';
  static const String _keyBingApiKey = 'bing_api_key';
  static const String _keyYandexOAuthToken = 'yandex_oauth_token';
  static const String _keyYandexClientId = 'yandex_client_id';
  static const String _keyHasCompletedOnboarding = 'has_completed_onboarding';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyAutoSyncEnabled = 'auto_sync_enabled';
  static const String _keyAutoSyncHour = 'auto_sync_hour';
  static const String _keyAutoSyncMinute = 'auto_sync_minute';
  static const String _keyAutoSyncDateWindowDays = 'auto_sync_date_window_days';
  static const String _keyLastSyncEpochMs = 'last_sync_epoch_ms';
  static const String _keyLastSyncStatus = 'last_sync_status';
  static const String _keyLastSyncSummaryJson = 'last_sync_summary_json';
  static const String _keyAlertRankGainThreshold = 'alert_rank_gain_threshold';
  static const String _keyAlertRankDropThreshold = 'alert_rank_drop_threshold';
  static const String _keyAlertRankGainEnabled = 'alert_rank_gain_enabled';
  static const String _keyAlertRankDropEnabled = 'alert_rank_drop_enabled';
  static const String _keyAlertNewQueryEnabled = 'alert_new_query_enabled';
  static const String _keyAlertLostQueryEnabled = 'alert_lost_query_enabled';
  static const String _keyAlertUrlChangeEnabled = 'alert_url_change_enabled';
  static const String _keyAlertCannibalizationEnabled =
      'alert_cannibalization_enabled';
  static const String _keyAlertNotificationsEnabled =
      'alert_notifications_enabled';

  // --- Safe Read & Write Helpers ---

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Fallback or handle storage error safely
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  // --- Onboarding Status ---

  Future<void> setCompletedOnboarding(bool completed) async {
    await _safeWrite(_keyHasCompletedOnboarding, completed ? 'true' : 'false');
  }

  Future<bool> hasCompletedOnboarding() async {
    final val = await _safeRead(_keyHasCompletedOnboarding);
    return val == 'true';
  }

  // --- Theme Mode Persistence ---

  Future<void> saveThemeMode(String mode) async {
    await _safeWrite(_keyThemeMode, mode);
  }

  Future<String?> getThemeMode() async {
    return await _safeRead(_keyThemeMode);
  }

  // --- Google Search Console Credentials ---

  Future<void> saveGscRefreshToken(String token) async {
    await _safeWrite(_keyGscRefreshToken, token.trim());
  }

  Future<String?> getGscRefreshToken() async {
    return await _safeRead(_keyGscRefreshToken);
  }

  Future<void> saveGscAccessToken(String token, [int? expiryEpochMs]) async {
    await _safeWrite(_keyGscAccessToken, token.trim());
    if (expiryEpochMs != null) {
      await _safeWrite(_keyGscTokenExpiry, expiryEpochMs.toString());
    } else {
      // Default expiry to 1 hour from now for manual token entries
      final defaultExpiry =
          DateTime.now().millisecondsSinceEpoch + (3600 * 1000);
      await _safeWrite(_keyGscTokenExpiry, defaultExpiry.toString());
    }
  }

  Future<String?> getGscAccessToken() async {
    return await _safeRead(_keyGscAccessToken);
  }

  Future<bool> isGscAccessTokenExpired() async {
    final expiryStr = await _safeRead(_keyGscTokenExpiry);
    if (expiryStr == null) {
      final token = await _safeRead(_keyGscAccessToken);
      return token == null || token.trim().isEmpty;
    }
    final expiry = int.tryParse(expiryStr) ?? 0;
    // Buffer with 60 seconds
    return DateTime.now().millisecondsSinceEpoch >= (expiry - 60000);
  }

  Future<void> saveGscClientId(String clientId) async {
    await _safeWrite(_keyGscClientId, clientId.trim());
  }

  Future<String?> getGscClientId() async {
    return await _safeRead(_keyGscClientId);
  }

  Future<void> clearGscClientId() async {
    await _safeDelete(_keyGscClientId);
  }

  Future<void> saveGscServerClientId(String serverClientId) async {
    await _safeWrite(_keyGscServerClientId, serverClientId.trim());
  }

  Future<String?> getGscServerClientId() async {
    return await _safeRead(_keyGscServerClientId);
  }

  Future<void> clearGscServerClientId() async {
    await _safeDelete(_keyGscServerClientId);
  }

  Future<void> saveGscUserEmail(String email) async {
    await _safeWrite(_keyGscUserEmail, email.trim());
  }

  Future<String?> getGscUserEmail() async {
    return await _safeRead(_keyGscUserEmail);
  }

  Future<void> saveGscUserDisplayName(String name) async {
    await _safeWrite(_keyGscUserDisplayName, name.trim());
  }

  Future<String?> getGscUserDisplayName() async {
    return await _safeRead(_keyGscUserDisplayName);
  }

  Future<void> saveGscLastVerified(int epochMs) async {
    await _safeWrite(_keyGscLastVerified, epochMs.toString());
  }

  Future<int?> getGscLastVerified() async {
    final str = await _safeRead(_keyGscLastVerified);
    return str != null ? int.tryParse(str) : null;
  }

  Future<void> clearGscCredentials() async {
    await _safeDelete(_keyGscRefreshToken);
    await _safeDelete(_keyGscAccessToken);
    await _safeDelete(_keyGscTokenExpiry);
    await _safeDelete(_keyGscUserEmail);
    await _safeDelete(_keyGscUserDisplayName);
    await _safeDelete(_keyGscLastVerified);
  }

  // --- Bing Webmaster Tools Credentials ---

  Future<void> saveBingApiKey(String apiKey) async {
    await _safeWrite(_keyBingApiKey, apiKey);
  }

  Future<String?> getBingApiKey() async {
    return await _safeRead(_keyBingApiKey);
  }

  Future<void> clearBingCredentials() async {
    await _safeDelete(_keyBingApiKey);
  }

  // --- Yandex Webmaster Credentials ---

  Future<void> saveYandexOAuthToken(String token) async {
    await _safeWrite(_keyYandexOAuthToken, token);
  }

  Future<String?> getYandexOAuthToken() async {
    return await _safeRead(_keyYandexOAuthToken);
  }

  Future<void> saveYandexClientId(String clientId) async {
    await _safeWrite(_keyYandexClientId, clientId);
  }

  Future<String?> getYandexClientId() async {
    return await _safeRead(_keyYandexClientId);
  }

  Future<void> clearYandexCredentials() async {
    await _safeDelete(_keyYandexOAuthToken);
    await _safeDelete(_keyYandexClientId);
  }

  // --- Auto Sync Preferences & State ---

  Future<void> setAutoSyncEnabled(bool enabled) async {
    await _safeWrite(_keyAutoSyncEnabled, enabled ? 'true' : 'false');
  }

  Future<bool> getAutoSyncEnabled() async {
    final val = await _safeRead(_keyAutoSyncEnabled);
    if (val == null) return true; // Default enabled
    return val == 'true';
  }

  Future<void> setAutoSyncHour(int hour) async {
    await _safeWrite(_keyAutoSyncHour, hour.toString());
  }

  Future<int> getAutoSyncHour() async {
    final val = await _safeRead(_keyAutoSyncHour);
    if (val == null) return 8; // Default 8:00 AM
    return int.tryParse(val) ?? 8;
  }

  Future<void> setAutoSyncMinute(int minute) async {
    await _safeWrite(_keyAutoSyncMinute, minute.toString());
  }

  Future<int> getAutoSyncMinute() async {
    final val = await _safeRead(_keyAutoSyncMinute);
    if (val == null) return 0;
    return int.tryParse(val) ?? 0;
  }

  Future<void> setAutoSyncDateWindowDays(int days) async {
    await _safeWrite(_keyAutoSyncDateWindowDays, days.toString());
  }

  Future<int> getAutoSyncDateWindowDays() async {
    final val = await _safeRead(_keyAutoSyncDateWindowDays);
    if (val == null) return 30; // Default 30 days
    return int.tryParse(val) ?? 30;
  }

  Future<void> setLastSyncEpochMs(int epochMs) async {
    await _safeWrite(_keyLastSyncEpochMs, epochMs.toString());
  }

  Future<int?> getLastSyncEpochMs() async {
    final val = await _safeRead(_keyLastSyncEpochMs);
    if (val == null) return null;
    return int.tryParse(val);
  }

  Future<void> setLastSyncStatus(String status) async {
    await _safeWrite(_keyLastSyncStatus, status);
  }

  Future<String?> getLastSyncStatus() async {
    return await _safeRead(_keyLastSyncStatus);
  }

  Future<void> saveLastSyncSummary(SyncSummary summary) async {
    await _safeWrite(_keyLastSyncSummaryJson, summary.toJson());
    await setLastSyncEpochMs(summary.completedAt.millisecondsSinceEpoch);
    await setLastSyncStatus(summary.status);
  }

  Future<SyncSummary?> getLastSyncSummary() async {
    final jsonStr = await _safeRead(_keyLastSyncSummaryJson);
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      return SyncSummary.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  DateTime calculateNextSyncTime({int? hour, int? minute, DateTime? from}) {
    final now = from ?? DateTime.now();
    final h = hour ?? 8;
    final m = minute ?? 0;
    final scheduledToday = DateTime(now.year, now.month, now.day, h, m);
    if (scheduledToday.isAfter(now)) {
      return scheduledToday;
    } else {
      return scheduledToday.add(const Duration(days: 1));
    }
  }

  // --- Alert Settings Persistence ---

  Future<AlertSettings> getAlertSettings() async {
    final gainThresh = await _safeRead(_keyAlertRankGainThreshold);
    final dropThresh = await _safeRead(_keyAlertRankDropThreshold);
    final gainEn = await _safeRead(_keyAlertRankGainEnabled);
    final dropEn = await _safeRead(_keyAlertRankDropEnabled);
    final newQEn = await _safeRead(_keyAlertNewQueryEnabled);
    final lostQEn = await _safeRead(_keyAlertLostQueryEnabled);
    final urlChEn = await _safeRead(_keyAlertUrlChangeEnabled);
    final cannEn = await _safeRead(_keyAlertCannibalizationEnabled);
    final notifEn = await _safeRead(_keyAlertNotificationsEnabled);

    return AlertSettings(
      rankGainThreshold: int.tryParse(gainThresh ?? '3') ?? 3,
      rankDropThreshold: int.tryParse(dropThresh ?? '3') ?? 3,
      rankGainEnabled: gainEn != 'false',
      rankDropEnabled: dropEn != 'false',
      newQueryEnabled: newQEn != 'false',
      lostQueryEnabled: lostQEn != 'false',
      urlChangeEnabled: urlChEn != 'false',
      cannibalizationEnabled: cannEn != 'false',
      localNotificationsEnabled: notifEn != 'false',
    );
  }

  Future<void> saveAlertSettings(AlertSettings settings) async {
    await _safeWrite(
      _keyAlertRankGainThreshold,
      settings.rankGainThreshold.toString(),
    );
    await _safeWrite(
      _keyAlertRankDropThreshold,
      settings.rankDropThreshold.toString(),
    );
    await _safeWrite(
      _keyAlertRankGainEnabled,
      settings.rankGainEnabled ? 'true' : 'false',
    );
    await _safeWrite(
      _keyAlertRankDropEnabled,
      settings.rankDropEnabled ? 'true' : 'false',
    );
    await _safeWrite(
      _keyAlertNewQueryEnabled,
      settings.newQueryEnabled ? 'true' : 'false',
    );
    await _safeWrite(
      _keyAlertLostQueryEnabled,
      settings.lostQueryEnabled ? 'true' : 'false',
    );
    await _safeWrite(
      _keyAlertUrlChangeEnabled,
      settings.urlChangeEnabled ? 'true' : 'false',
    );
    await _safeWrite(
      _keyAlertCannibalizationEnabled,
      settings.cannibalizationEnabled ? 'true' : 'false',
    );
    await _safeWrite(
      _keyAlertNotificationsEnabled,
      settings.localNotificationsEnabled ? 'true' : 'false',
    );
  }

  // --- Backup & Restore of Stored Credentials ---

  Future<Map<String, String>> getAllCredentials() async {
    final Map<String, String> creds = {};
    final gscRefresh = await getGscRefreshToken();
    if (gscRefresh != null) creds[_keyGscRefreshToken] = gscRefresh;
    final gscAccess = await getGscAccessToken();
    if (gscAccess != null) creds[_keyGscAccessToken] = gscAccess;
    final gscExpiry = await _safeRead(_keyGscTokenExpiry);
    if (gscExpiry != null) creds[_keyGscTokenExpiry] = gscExpiry;
    final gscClient = await getGscClientId();
    if (gscClient != null) creds[_keyGscClientId] = gscClient;
    final gscServerClient = await getGscServerClientId();
    if (gscServerClient != null) creds[_keyGscServerClientId] = gscServerClient;
    final gscEmail = await getGscUserEmail();
    if (gscEmail != null) creds[_keyGscUserEmail] = gscEmail;
    final gscName = await getGscUserDisplayName();
    if (gscName != null) creds[_keyGscUserDisplayName] = gscName;
    final gscVerified = await _safeRead(_keyGscLastVerified);
    if (gscVerified != null) creds[_keyGscLastVerified] = gscVerified;
    final bingKey = await getBingApiKey();
    if (bingKey != null) creds[_keyBingApiKey] = bingKey;
    final yandexToken = await getYandexOAuthToken();
    if (yandexToken != null) creds[_keyYandexOAuthToken] = yandexToken;
    final yandexClient = await getYandexClientId();
    if (yandexClient != null) creds[_keyYandexClientId] = yandexClient;
    final theme = await getThemeMode();
    if (theme != null) creds[_keyThemeMode] = theme;
    final autoSync = await _safeRead(_keyAutoSyncEnabled);
    if (autoSync != null) creds[_keyAutoSyncEnabled] = autoSync;
    final autoHour = await _safeRead(_keyAutoSyncHour);
    if (autoHour != null) creds[_keyAutoSyncHour] = autoHour;
    final autoMin = await _safeRead(_keyAutoSyncMinute);
    if (autoMin != null) creds[_keyAutoSyncMinute] = autoMin;
    final dateWindow = await _safeRead(_keyAutoSyncDateWindowDays);
    if (dateWindow != null) creds[_keyAutoSyncDateWindowDays] = dateWindow;
    final gainThresh = await _safeRead(_keyAlertRankGainThreshold);
    if (gainThresh != null) creds[_keyAlertRankGainThreshold] = gainThresh;
    final dropThresh = await _safeRead(_keyAlertRankDropThreshold);
    if (dropThresh != null) creds[_keyAlertRankDropThreshold] = dropThresh;
    final gainEn = await _safeRead(_keyAlertRankGainEnabled);
    if (gainEn != null) creds[_keyAlertRankGainEnabled] = gainEn;
    final dropEn = await _safeRead(_keyAlertRankDropEnabled);
    if (dropEn != null) creds[_keyAlertRankDropEnabled] = dropEn;
    final notifEn = await _safeRead(_keyAlertNotificationsEnabled);
    if (notifEn != null) creds[_keyAlertNotificationsEnabled] = notifEn;
    return creds;
  }

  Future<void> restoreCredentials(Map<String, dynamic> creds) async {
    for (final entry in creds.entries) {
      if (entry.value != null) {
        await _safeWrite(entry.key, entry.value.toString());
      }
    }
  }

  // --- Purge All Sensitive State ---

  Future<void> clearAllCredentials() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
