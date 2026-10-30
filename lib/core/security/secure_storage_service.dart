import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure hardware-backed storage for API keys and OAuth tokens using Android KeyStore.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
            );

  static const String _keyGscRefreshToken = 'gsc_refresh_token';
  static const String _keyGscAccessToken = 'gsc_access_token';
  static const String _keyGscTokenExpiry = 'gsc_token_expiry';
  static const String _keyGscClientId = 'gsc_client_id';
  static const String _keyBingApiKey = 'bing_api_key';

  // --- Google Search Console Credentials ---

  Future<void> saveGscRefreshToken(String token) async {
    await _storage.write(key: _keyGscRefreshToken, value: token);
  }

  Future<String?> getGscRefreshToken() async {
    return await _storage.read(key: _keyGscRefreshToken);
  }

  Future<void> saveGscAccessToken(String token, int expiryEpochMs) async {
    await _storage.write(key: _keyGscAccessToken, value: token);
    await _storage.write(key: _keyGscTokenExpiry, value: expiryEpochMs.toString());
  }

  Future<String?> getGscAccessToken() async {
    return await _storage.read(key: _keyGscAccessToken);
  }

  Future<bool> isGscAccessTokenExpired() async {
    final expiryStr = await _storage.read(key: _keyGscTokenExpiry);
    if (expiryStr == null) return true;
    final expiry = int.tryParse(expiryStr) ?? 0;
    // Buffer with 60 seconds
    return DateTime.now().millisecondsSinceEpoch >= (expiry - 60000);
  }

  Future<void> saveGscClientId(String clientId) async {
    await _storage.write(key: _keyGscClientId, value: clientId);
  }

  Future<String?> getGscClientId() async {
    return await _storage.read(key: _keyGscClientId);
  }

  Future<void> clearGscCredentials() async {
    await _storage.delete(key: _keyGscRefreshToken);
    await _storage.delete(key: _keyGscAccessToken);
    await _storage.delete(key: _keyGscTokenExpiry);
  }

  // --- Bing Webmaster Tools Credentials ---

  Future<void> saveBingApiKey(String apiKey) async {
    await _storage.write(key: _keyBingApiKey, value: apiKey);
  }

  Future<String?> getBingApiKey() async {
    return await _storage.read(key: _keyBingApiKey);
  }

  Future<void> clearBingCredentials() async {
    await _storage.delete(key: _keyBingApiKey);
  }

  // --- Backup & Restore of Stored Credentials ---

  Future<Map<String, String>> getAllCredentials() async {
    final Map<String, String> creds = {};
    final gscRefresh = await getGscRefreshToken();
    if (gscRefresh != null) creds[_keyGscRefreshToken] = gscRefresh;
    final gscAccess = await getGscAccessToken();
    if (gscAccess != null) creds[_keyGscAccessToken] = gscAccess;
    final gscExpiry = await _storage.read(key: _keyGscTokenExpiry);
    if (gscExpiry != null) creds[_keyGscTokenExpiry] = gscExpiry;
    final gscClient = await getGscClientId();
    if (gscClient != null) creds[_keyGscClientId] = gscClient;
    final bingKey = await getBingApiKey();
    if (bingKey != null) creds[_keyBingApiKey] = bingKey;
    return creds;
  }

  Future<void> restoreCredentials(Map<String, dynamic> creds) async {
    for (final entry in creds.entries) {
      if (entry.value != null) {
        await _storage.write(key: entry.key, value: entry.value.toString());
      }
    }
  }

  // --- Purge All Sensitive State ---

  Future<void> clearAllCredentials() async {
    await _storage.deleteAll();
  }
}
