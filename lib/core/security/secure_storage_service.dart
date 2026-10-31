import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  static const String _keyGscUserEmail = 'gsc_user_email';
  static const String _keyGscUserDisplayName = 'gsc_user_display_name';
  static const String _keyGscLastVerified = 'gsc_last_verified';
  static const String _keyBingApiKey = 'bing_api_key';
  static const String _keyYandexOAuthToken = 'yandex_oauth_token';
  static const String _keyYandexClientId = 'yandex_client_id';
  static const String _keyHasCompletedOnboarding = 'has_completed_onboarding';
  static const String _keyThemeMode = 'app_theme_mode';

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
    await _safeWrite(_keyGscClientId, clientId);
  }

  Future<String?> getGscClientId() async {
    return await _safeRead(_keyGscClientId);
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
