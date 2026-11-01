import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/features/settings/presentation/views/settings_view.dart';

import '../../test_helper.dart';

class _FakeSettingsSecureStorage extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<String?> getGscClientId() async => _data['gsc_client_id'];
  @override
  Future<void> saveGscClientId(String id) async => _data['gsc_client_id'] = id;
  @override
  Future<void> clearGscClientId() async => _data.remove('gsc_client_id');

  @override
  Future<String?> getGscServerClientId() async => _data['gsc_server_client_id'];
  @override
  Future<void> saveGscServerClientId(String id) async =>
      _data['gsc_server_client_id'] = id;
  @override
  Future<void> clearGscServerClientId() async =>
      _data.remove('gsc_server_client_id');

  @override
  Future<String?> getGscAccessToken() async => _data['gsc_access_token'];
  @override
  Future<void> saveGscAccessToken(String token, [int? expiryEpochMs]) async =>
      _data['gsc_access_token'] = token;

  @override
  Future<String?> getGscRefreshToken() async => _data['gsc_refresh_token'];
  @override
  Future<void> saveGscRefreshToken(String token) async =>
      _data['gsc_refresh_token'] = token;

  @override
  Future<String?> getGscUserEmail() async => _data['gsc_user_email'];
  @override
  Future<void> saveGscUserEmail(String email) async =>
      _data['gsc_user_email'] = email;

  @override
  Future<String?> getBingApiKey() async => _data['bing_api_key'];
  @override
  Future<String?> getYandexOAuthToken() async => _data['yandex_oauth_token'];

  @override
  Future<void> clearGscCredentials() async {
    _data.remove('gsc_access_token');
    _data.remove('gsc_refresh_token');
    _data.remove('gsc_token_expiry');
    _data.remove('gsc_user_email');
    _data.remove('gsc_user_display_name');
    _data.remove('gsc_last_verified');
  }

  @override
  Future<Map<String, String>> getAllCredentials() async => Map.from(_data);

  @override
  Future<void> restoreCredentials(Map<String, dynamic> creds) async {
    for (final e in creds.entries) {
      if (e.value != null) _data[e.key] = e.value.toString();
    }
  }
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  group('Google OAuth Settings Dual Client ID Tests', () {
    test('SecureStorage preserves Android and Web Client IDs independently', () async {
      final storage = _FakeSettingsSecureStorage();

      await storage.saveGscClientId('android-client-123.apps.googleusercontent.com');
      await storage.saveGscServerClientId('web-server-client-456.apps.googleusercontent.com');

      expect(await storage.getGscClientId(), 'android-client-123.apps.googleusercontent.com');
      expect(await storage.getGscServerClientId(), 'web-server-client-456.apps.googleusercontent.com');

      // Clear Android client ID only
      await storage.clearGscClientId();
      expect(await storage.getGscClientId(), isNull);
      expect(await storage.getGscServerClientId(), 'web-server-client-456.apps.googleusercontent.com');

      // Disconnect session clears tokens but preserves both client IDs
      await storage.saveGscClientId('android-client-123.apps.googleusercontent.com');
      await storage.saveGscAccessToken('ya29.test_token');
      await storage.clearGscCredentials();

      expect(await storage.getGscAccessToken(), isNull);
      expect(await storage.getGscClientId(), 'android-client-123.apps.googleusercontent.com');
      expect(await storage.getGscServerClientId(), 'web-server-client-456.apps.googleusercontent.com');
    });

    test('SecureStorage getAllCredentials & restoreCredentials include Web Client ID', () async {
      final storage = _FakeSettingsSecureStorage();

      await storage.saveGscClientId('android-id');
      await storage.saveGscServerClientId('web-server-id');

      final all = await storage.getAllCredentials();
      expect(all['gsc_client_id'], 'android-id');
      expect(all['gsc_server_client_id'], 'web-server-id');

      final newStorage = _FakeSettingsSecureStorage();
      await newStorage.restoreCredentials(all);

      expect(await newStorage.getGscClientId(), 'android-id');
      expect(await newStorage.getGscServerClientId(), 'web-server-id');
    });

    testWidgets('SettingsView renders separate labels for Android Client ID and Web Client ID', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = _FakeSettingsSecureStorage();
      await storage.saveGscClientId('my-android-client.apps.googleusercontent.com');
      await storage.saveGscServerClientId('my-web-client.apps.googleusercontent.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageServiceProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for clearly labelled headings
      expect(find.text('Android OAuth Client ID'), findsOneWidget);
      expect(find.text('Web OAuth Client ID / Server Client ID'), findsOneWidget);
      expect(find.text('Package Name: '), findsOneWidget);
      expect(find.text('SHA-1: '), findsOneWidget);

      // Verify fields loaded existing values
      expect(find.text('my-android-client.apps.googleusercontent.com'), findsOneWidget);
      expect(find.text('my-web-client.apps.googleusercontent.com'), findsOneWidget);
    });
  });
}
