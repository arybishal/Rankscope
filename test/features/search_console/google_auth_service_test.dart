import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rankscope/core/errors/exceptions.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:rankscope/features/search_console/data/datasources/remote_gsc_datasource.dart';
import 'package:rankscope/features/search_console/presentation/controllers/gsc_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? clientId;
  String? accessToken;
  String? refreshToken;
  String? userEmail;
  String? userDisplayName;
  int? lastVerified;
  bool tokenExpired = false;

  @override
  Future<String?> getGscClientId() async => clientId;
  @override
  Future<void> saveGscClientId(String id) async => clientId = id;

  @override
  Future<String?> getGscAccessToken() async => accessToken;
  @override
  Future<void> saveGscAccessToken(String token, [int? expiryEpochMs]) async {
    accessToken = token;
    tokenExpired = false;
  }

  @override
  Future<String?> getGscRefreshToken() async => refreshToken;
  @override
  Future<void> saveGscRefreshToken(String token) async => refreshToken = token;

  @override
  Future<String?> getGscUserEmail() async => userEmail;
  @override
  Future<void> saveGscUserEmail(String email) async => userEmail = email;

  @override
  Future<String?> getGscUserDisplayName() async => userDisplayName;
  @override
  Future<void> saveGscUserDisplayName(String name) async => userDisplayName = name;

  @override
  Future<int?> getGscLastVerified() async => lastVerified;
  @override
  Future<void> saveGscLastVerified(int epochMs) async => lastVerified = epochMs;

  @override
  Future<bool> isGscAccessTokenExpired() async => tokenExpired;

  @override
  Future<void> clearGscCredentials() async {
    clientId = null;
    accessToken = null;
    refreshToken = null;
    userEmail = null;
    userDisplayName = null;
    lastVerified = null;
  }
}

class _FakeRemoteGscDatasource extends RemoteGscDatasource {
  List<String> mockSites = ['https://example.com/'];
  int statusCodeToThrow = 200;
  String? errorMessageToThrow;

  @override
  Future<List<String>> listVerifiedSites() async {
    if (statusCodeToThrow == 401) {
      throw const NetworkException('Invalid or expired token', statusCode: 401);
    }
    if (statusCodeToThrow == 403) {
      throw const NetworkException('GSC API disabled or forbidden', statusCode: 403);
    }
    if (errorMessageToThrow != null) {
      throw NetworkException(errorMessageToThrow!, statusCode: 500);
    }
    return mockSites;
  }
}

class _FakeGoogleSignInAdapter implements GoogleSignInAdapter {
  bool throwCancellation = false;
  bool throwError = false;
  bool signedOut = false;
  String returnEmail = 'developer@rankscope.com';
  String returnAccessToken = 'ya29.fake_test_token';

  @override
  Future<void> initialize({String? clientId, String? serverClientId}) async {}

  @override
  Future<GoogleAccountResult> authenticateAndAuthorize({
    required List<String> scopes,
  }) async {
    if (throwCancellation) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'User canceled sign-in',
      );
    }
    if (throwError) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Google Play Services unavailable',
      );
    }
    return GoogleAccountResult(
      email: returnEmail,
      displayName: 'Test Developer',
      accessToken: returnAccessToken,
    );
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorage storage;
  late _FakeRemoteGscDatasource remoteDatasource;
  late _FakeGoogleSignInAdapter signInAdapter;
  late GoogleAuthService authService;

  setUp(() {
    storage = _FakeSecureStorage();
    remoteDatasource = _FakeRemoteGscDatasource();
    signInAdapter = _FakeGoogleSignInAdapter();
    authService = GoogleAuthService(
      signInAdapter: signInAdapter,
      secureStorage: storage,
      remoteDatasource: remoteDatasource,
    );
  });

  group('Google Search Console 6 Connection States & AuthService Tests', () {
    test('1. Returns Not Configured when storage has no credentials', () async {
      final status = await authService.checkConnectionStatus();
      expect(status.state, GscConnectionState.notConfigured);
      expect(status.isNotConfigured, isTrue);
      expect(status.label, 'Not Configured');
    });

    test('2. Returns Ready to Connect when Client ID is configured but not authorized', () async {
      storage.clientId = '123456789-abcdef.apps.googleusercontent.com';

      final status = await authService.checkConnectionStatus();
      expect(status.state, GscConnectionState.readyToConnect);
      expect(status.isReadyToConnect, isTrue);
      expect(status.label, 'Ready to Connect');
      expect(status.message, contains('123456789-abcdef'));
    });

    test('3. Returns Action Required when access token is expired and no refresh token exists', () async {
      storage.accessToken = 'expired_token';
      storage.tokenExpired = true;

      final status = await authService.checkConnectionStatus();
      expect(status.state, GscConnectionState.actionRequired);
      expect(status.isActionRequired, isTrue);
      expect(status.label, 'Action Required');
    });

    test('4. Returns Connected when token is valid and API responds with verified sites', () async {
      storage.accessToken = 'valid_token';
      storage.userEmail = 'dev@rankscope.com';
      remoteDatasource.mockSites = ['https://mysite.com/', 'sc-domain:mysite.com'];

      final status = await authService.checkConnectionStatus(verifyWithApi: true);
      expect(status.state, GscConnectionState.connected);
      expect(status.isConnected, isTrue);
      expect(status.verifiedSites, hasLength(2));
      expect(status.userEmail, 'dev@rankscope.com');
      expect(storage.lastVerified, isNotNull);
    });

    test('5. Returns Action Required when API returns 401 unauthorized', () async {
      storage.accessToken = 'revoked_token';
      remoteDatasource.statusCodeToThrow = 401;

      final status = await authService.checkConnectionStatus(verifyWithApi: true);
      expect(status.state, GscConnectionState.actionRequired);
      expect(status.isActionRequired, isTrue);
      expect(status.message, contains('401'));
    });

    test('6. Returns Connection Error with cloud guidance when API returns 403', () async {
      storage.accessToken = 'valid_token';
      remoteDatasource.statusCodeToThrow = 403;

      final status = await authService.checkConnectionStatus(verifyWithApi: true);
      expect(status.state, GscConnectionState.connectionError);
      expect(status.isError, isTrue);
      expect(status.message, contains('403'));
      expect(status.message, contains('Google Search Console API'));
    });

    test('7. signInAndAuthorize successfully logs in and transitions to Connected', () async {
      final status = await authService.signInAndAuthorize(
        clientId: 'custom-client-id.apps.googleusercontent.com',
      );

      expect(status.state, GscConnectionState.connected);
      expect(status.userEmail, 'developer@rankscope.com');
      expect(storage.accessToken, 'ya29.fake_test_token');
      expect(storage.userEmail, 'developer@rankscope.com');
      expect(storage.clientId, 'custom-client-id.apps.googleusercontent.com');
    });

    test('8. signInAndAuthorize handles user cancellation gracefully', () async {
      storage.clientId = 'client_123';
      signInAdapter.throwCancellation = true;

      final status = await authService.signInAndAuthorize();
      expect(status.state, GscConnectionState.readyToConnect);
      expect(status.message, contains('cancelled'));
    });

    test('9. disconnect signs out and clears credentials', () async {
      storage.accessToken = 'valid_token';
      storage.userEmail = 'dev@rankscope.com';

      final status = await authService.disconnect();
      expect(status.state, GscConnectionState.notConfigured);
      expect(signInAdapter.signedOut, isTrue);
      expect(storage.accessToken, isNull);
      expect(storage.userEmail, isNull);
    });
  });

  group('Overview Connection Chip Rendering Tests', () {
    testWidgets('Displays Google Search Console: Ready to Connect chip when status is readyToConnect', (tester) async {
      final fakeWebsite = Website(
        id: 1,
        domain: 'example.com',
        label: 'Example Site',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(
              () => _FakeWebsitesNotifier([fakeWebsite]),
            ),
            selectedWebsiteIdProvider.overrideWith(
              () => _TestSelectedWebsiteIdNotifier(1),
            ),
            gscConnectionStatusProvider.overrideWith(
              () => _MockGscStatusNotifier(
                GscConnectionStatus.readyToConnect(
                  clientId: 'sample_id',
                  message: 'OAuth Client ID configured',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Google Search Console: Ready to Connect'), findsOneWidget);
    });

    testWidgets('Displays Google Search Console: Connected chip when status is connected', (tester) async {
      final fakeWebsite = Website(
        id: 1,
        domain: 'example.com',
        label: 'Example Site',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            websitesProvider.overrideWith(
              () => _FakeWebsitesNotifier([fakeWebsite]),
            ),
            selectedWebsiteIdProvider.overrideWith(
              () => _TestSelectedWebsiteIdNotifier(1),
            ),
            gscConnectionStatusProvider.overrideWith(
              () => _MockGscStatusNotifier(
                GscConnectionStatus.connected(
                  userEmail: 'seo@example.com',
                  verifiedSites: ['https://example.com/'],
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Google Search Console: Connected'), findsOneWidget);
    });
  });
}

class _FakeWebsitesNotifier extends WebsitesNotifier {
  final List<Website> _initial;
  _FakeWebsitesNotifier(this._initial);

  @override
  Future<List<Website>> build() async => _initial;
}

class _TestSelectedWebsiteIdNotifier extends SelectedWebsiteIdNotifier {
  final int? _initialId;
  _TestSelectedWebsiteIdNotifier(this._initialId);

  @override
  int? build() => _initialId;
}

class _MockGscStatusNotifier extends GscConnectionStatusNotifier {
  final GscConnectionStatus initial;
  _MockGscStatusNotifier(this.initial);

  @override
  Future<GscConnectionStatus> build() async => initial;
}
