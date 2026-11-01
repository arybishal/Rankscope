import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../datasources/remote_gsc_datasource.dart';

/// 6 distinct Google Search Console connection states.
enum GscConnectionState {
  /// OAuth credentials missing or invalid.
  notConfigured,

  /// Client ID is configured, but authorization has not occurred yet.
  readyToConnect,

  /// Authorization or verification in progress.
  connecting,

  /// Valid authorization exists AND real Search Console API connection is confirmed.
  connected,

  /// Authorization expired, revoked, or requires user action.
  actionRequired,

  /// API 403, permission, or network error.
  connectionError,
}

/// Rich status model for Google Search Console integration.
@immutable
class GscConnectionStatus {
  final GscConnectionState state;
  final String label;
  final String message;
  final String? userEmail;
  final String? userDisplayName;
  final List<String> verifiedSites;
  final DateTime? lastVerifiedAt;

  const GscConnectionStatus({
    required this.state,
    required this.label,
    required this.message,
    this.userEmail,
    this.userDisplayName,
    this.verifiedSites = const [],
    this.lastVerifiedAt,
  });

  bool get isConnected => state == GscConnectionState.connected;
  bool get isReadyToConnect => state == GscConnectionState.readyToConnect;
  bool get isConnecting => state == GscConnectionState.connecting;
  bool get isActionRequired => state == GscConnectionState.actionRequired;
  bool get isError => state == GscConnectionState.connectionError;
  bool get isNotConfigured => state == GscConnectionState.notConfigured;

  factory GscConnectionStatus.notConfigured({String? message}) =>
      GscConnectionStatus(
        state: GscConnectionState.notConfigured,
        label: 'Not Configured',
        message:
            message ??
            'Enter your Google OAuth Client ID or connect with Google to begin.',
      );

  factory GscConnectionStatus.readyToConnect({
    String? clientId,
    String? message,
  }) => GscConnectionStatus(
    state: GscConnectionState.readyToConnect,
    label: 'Ready to Connect',
    message:
        message ??
        'OAuth credentials configured. Tap to authorize your Google Account.',
  );

  factory GscConnectionStatus.connecting({String? message}) =>
      GscConnectionStatus(
        state: GscConnectionState.connecting,
        label: 'Connecting...',
        message:
            message ??
            'Authorizing with Google and verifying Search Console access...',
      );

  factory GscConnectionStatus.connected({
    String? userEmail,
    String? userDisplayName,
    List<String> verifiedSites = const [],
    DateTime? lastVerifiedAt,
    String? message,
  }) => GscConnectionStatus(
    state: GscConnectionState.connected,
    label: 'Connected',
    message:
        message ??
        (verifiedSites.isNotEmpty
            ? 'Connected and verified with Google Search Console (${verifiedSites.length} site(s)).'
            : 'Connected with Google Search Console API.'),
    userEmail: userEmail,
    userDisplayName: userDisplayName,
    verifiedSites: verifiedSites,
    lastVerifiedAt: lastVerifiedAt ?? DateTime.now(),
  );

  factory GscConnectionStatus.actionRequired({
    required String message,
    String? userEmail,
  }) => GscConnectionStatus(
    state: GscConnectionState.actionRequired,
    label: 'Action Required',
    message: message,
    userEmail: userEmail,
  );

  factory GscConnectionStatus.connectionError(
    String error, {
    String? userEmail,
  }) => GscConnectionStatus(
    state: GscConnectionState.connectionError,
    label: 'Connection Error',
    message: error,
    userEmail: userEmail,
  );

  GscConnectionStatus copyWith({
    GscConnectionState? state,
    String? label,
    String? message,
    String? userEmail,
    String? userDisplayName,
    List<String>? verifiedSites,
    DateTime? lastVerifiedAt,
  }) {
    return GscConnectionStatus(
      state: state ?? this.state,
      label: label ?? this.label,
      message: message ?? this.message,
      userEmail: userEmail ?? this.userEmail,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      verifiedSites: verifiedSites ?? this.verifiedSites,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}

/// DTO for Google Account Authentication & Authorization tokens.
class GoogleAccountResult {
  final String email;
  final String? displayName;
  final String accessToken;

  const GoogleAccountResult({
    required this.email,
    this.displayName,
    required this.accessToken,
  });
}

/// Adapter interface for Google Sign-In to allow isolated unit testing.
abstract class GoogleSignInAdapter {
  Future<void> initialize({String? clientId, String? serverClientId});
  Future<GoogleAccountResult> authenticateAndAuthorize({
    required List<String> scopes,
    String? clientId,
    String? serverClientId,
  });
  Future<void> signOut();
  Future<String?> getFreshAccessToken({required List<String> scopes});
}

/// Default production adapter using the official `google_sign_in` plugin.
class DefaultGoogleSignInAdapter implements GoogleSignInAdapter {
  Future<void>? _initFuture;
  String? _initializedServerClientId;
  String? _initializedClientId;

  @override
  Future<void> initialize({String? clientId, String? serverClientId}) async {
    final sanitizedClientId =
        clientId?.isNotEmpty == true ? clientId!.trim() : null;
    final sanitizedServerClientId =
        serverClientId?.isNotEmpty == true ? serverClientId!.trim() : null;

    if (_initFuture == null) {
      _initFuture = () async {
        try {
          await GoogleSignIn.instance.initialize(
            clientId: sanitizedClientId,
            serverClientId: sanitizedServerClientId,
          );
          _initializedClientId = sanitizedClientId;
          _initializedServerClientId = sanitizedServerClientId;
        } catch (_) {
          _initializedClientId = sanitizedClientId;
          _initializedServerClientId = sanitizedServerClientId;
        }
      }();
      await _initFuture;
    } else {
      await _initFuture;
      // If serverClientId or clientId changed, update the underlying platform instance directly
      // without calling GoogleSignIn.instance.initialize a second time.
      if (sanitizedServerClientId != _initializedServerClientId ||
          sanitizedClientId != _initializedClientId) {
        try {
          await GoogleSignInPlatform.instance.init(
            InitParameters(
              clientId: sanitizedClientId,
              serverClientId: sanitizedServerClientId,
            ),
          );
          _initializedClientId = sanitizedClientId;
          _initializedServerClientId = sanitizedServerClientId;
        } catch (_) {}
      }
    }
  }

  @override
  Future<GoogleAccountResult> authenticateAndAuthorize({
    required List<String> scopes,
    String? clientId,
    String? serverClientId,
  }) async {
    // Ensure initialized and awaited before authenticating
    await initialize(clientId: clientId, serverClientId: serverClientId);

    final account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    final authz = await account.authorizationClient.authorizeScopes(scopes);

    return GoogleAccountResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: authz.accessToken,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  @override
  Future<String?> getFreshAccessToken({required List<String> scopes}) async {
    try {
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) {
        final authz =
            await account.authorizationClient.authorizationForScopes(scopes);
        if (authz?.accessToken.isNotEmpty == true) {
          return authz!.accessToken;
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Primary service managing Google Search Console authentication,
/// token persistence, and connection state transitions.
class GoogleAuthService {
  final GoogleSignInAdapter _signInAdapter;
  final SecureStorageService _secureStorage;
  final RemoteGscDatasource _remoteDatasource;

  static const String searchConsoleReadOnlyScope =
      'https://www.googleapis.com/auth/webmasters.readonly';

  GoogleAuthService({
    GoogleSignInAdapter? signInAdapter,
    SecureStorageService? secureStorage,
    RemoteGscDatasource? remoteDatasource,
  }) : _signInAdapter = signInAdapter ?? DefaultGoogleSignInAdapter(),
       _secureStorage = secureStorage ?? SecureStorageService(),
       _remoteDatasource = remoteDatasource ?? RemoteGscDatasource();

  /// Inspects local credentials and determines the current connection status.
  /// If [verifyWithApi] is true, triggers a live REST call to `/sites` to confirm
  /// valid API access.
  Future<GscConnectionStatus> checkConnectionStatus({
    bool verifyWithApi = false,
  }) async {
    try {
      final clientId = await _secureStorage.getGscClientId();
      final serverClientId = await _secureStorage.getGscServerClientId();
      final accessToken = await _secureStorage.getGscAccessToken();
      final refreshToken = await _secureStorage.getGscRefreshToken();
      final userEmail = await _secureStorage.getGscUserEmail();
      final userDisplayName = await _secureStorage.getGscUserDisplayName();
      final lastVerifiedEpoch = await _secureStorage.getGscLastVerified();

      // Case 1: No access token and no refresh token
      if ((accessToken == null || accessToken.isEmpty) &&
          (refreshToken == null || refreshToken.isEmpty)) {
        if ((serverClientId != null && serverClientId.trim().isNotEmpty) ||
            (clientId != null && clientId.trim().isNotEmpty)) {
          final displayId = (serverClientId?.isNotEmpty == true)
              ? serverClientId!.trim()
              : clientId!.trim();
          return GscConnectionStatus.readyToConnect(
            clientId: displayId,
            message:
                'OAuth Client ID configured ($displayId). Tap "Connect with Google" to authorize Search Console.',
          );
        }
        return GscConnectionStatus.notConfigured();
      }

      // Case 2: Token exists, check expiration
      final isExpired = await _secureStorage.isGscAccessTokenExpired();
      if (isExpired && (refreshToken == null || refreshToken.isEmpty)) {
        // Attempt silent refresh before marking actionRequired
        final freshToken = await _signInAdapter.getFreshAccessToken(
          scopes: [searchConsoleReadOnlyScope],
        );
        if (freshToken != null && freshToken.isNotEmpty) {
          await _secureStorage.saveGscAccessToken(freshToken);
        } else {
          return GscConnectionStatus.actionRequired(
            message:
                'Google authorization token has expired. Please re-authorize.',
            userEmail: userEmail,
          );
        }
      }

      // Case 3: Need API verification
      if (verifyWithApi || lastVerifiedEpoch == null) {
        return await verifySearchConsoleAccess();
      }

      // Case 4: Known valid active session
      final lastVerifiedDate = DateTime.fromMillisecondsSinceEpoch(
        lastVerifiedEpoch,
      );
      return GscConnectionStatus.connected(
        userEmail: userEmail,
        userDisplayName: userDisplayName,
        lastVerifiedAt: lastVerifiedDate,
      );
    } catch (e) {
      return GscConnectionStatus.connectionError(
        'Failed to check connection status: $e',
      );
    }
  }

  /// Initiates interactive Google Sign-In and requests Search Console scopes.
  Future<GscConnectionStatus> signInAndAuthorize({
    String? clientId,
    String? serverClientId,
  }) async {
    try {
      final effectiveClientId =
          clientId ?? await _secureStorage.getGscClientId();
      final effectiveServerClientId =
          serverClientId ?? await _secureStorage.getGscServerClientId();

      // On Android, Google Credential Manager requires a Web OAuth Client ID (serverClientId)
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (effectiveServerClientId == null ||
            effectiveServerClientId.trim().isEmpty) {
          await AppLogger.instance.warning(
            'GoogleAuthService',
            'missing_server_client_id',
            'Attempted Google Sign-In on Android without serverClientId configured.',
          );
          return GscConnectionStatus.connectionError(
            'Google Sign-In failed: serverClientId must be provided on Android. '
            'Please configure your Web application OAuth Client ID (serverClientId) in Settings > Google Search Console API.',
          );
        }
      }

      // 1. Initialize Google Sign-In exactly once and await completion
      await _signInAdapter.initialize(
        clientId: effectiveClientId,
        serverClientId: effectiveServerClientId,
      );

      // 2. Perform interactive authentication and scope authorization
      final result = await _signInAdapter.authenticateAndAuthorize(
        scopes: [searchConsoleReadOnlyScope],
        clientId: effectiveClientId,
        serverClientId: effectiveServerClientId,
      );

      // 3. Persist tokens and identity safely
      await _secureStorage.saveGscAccessToken(result.accessToken);
      await _secureStorage.saveGscUserEmail(result.email);
      if (result.displayName != null && result.displayName!.isNotEmpty) {
        await _secureStorage.saveGscUserDisplayName(result.displayName!);
      }
      if (effectiveClientId != null && effectiveClientId.isNotEmpty) {
        await _secureStorage.saveGscClientId(effectiveClientId);
      }
      if (effectiveServerClientId != null &&
          effectiveServerClientId.isNotEmpty) {
        await _secureStorage.saveGscServerClientId(effectiveServerClientId);
      }

      await AppLogger.instance.info(
        'GoogleAuthService',
        'oauth_authorized',
        'Google account authorized for ${result.email}',
      );

      // 4. Immediately verify with official Search Console REST API before displaying Connected
      return await verifySearchConsoleAccess();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        final current = await checkConnectionStatus(verifyWithApi: false);
        return current.copyWith(
          message: 'Google Sign-In was cancelled by user.',
        );
      }
      final err = e.description ?? e.code.name;
      await AppLogger.instance.error(
        'GoogleAuthService',
        'oauth_failed',
        'Google Sign-In exception: $err',
      );
      return GscConnectionStatus.connectionError('Google Sign-In failed: $err');
    } catch (e) {
      await AppLogger.instance.error(
        'GoogleAuthService',
        'oauth_failed',
        'OAuth authorization error: $e',
      );
      return GscConnectionStatus.connectionError(
        'Authorization failed: $e. Verify network and Google Cloud Console configuration.',
      );
    }
  }

  /// Hits the official Google Search Console `/sites` API to confirm live access.
  Future<GscConnectionStatus> verifySearchConsoleAccess() async {
    final userEmail = await _secureStorage.getGscUserEmail();
    final userDisplayName = await _secureStorage.getGscUserDisplayName();

    try {
      final sites = await _remoteDatasource.listVerifiedSites();
      final now = DateTime.now();
      await _secureStorage.saveGscLastVerified(now.millisecondsSinceEpoch);

      await AppLogger.instance.info(
        'GoogleAuthService',
        'api_verified',
        'Search Console API verified with ${sites.length} site(s)',
      );

      return GscConnectionStatus.connected(
        userEmail: userEmail,
        userDisplayName: userDisplayName,
        verifiedSites: sites,
        lastVerifiedAt: now,
      );
    } on NetworkException catch (e) {
      await AppLogger.instance.error(
        'GoogleAuthService',
        'verify_failed',
        'NetworkException during GSC verification: ${e.statusCode} ${e.message}',
      );

      if (e.statusCode == 401) {
        return GscConnectionStatus.actionRequired(
          message:
              'Authorization token is invalid or expired (401). Tap to re-authorize.',
          userEmail: userEmail,
        );
      } else if (e.statusCode == 403) {
        return GscConnectionStatus.connectionError(
          'Access forbidden (403): Ensure the "Google Search Console API" is enabled in Google Cloud Console for your project and your account has permissions.',
          userEmail: userEmail,
        );
      } else {
        return GscConnectionStatus.connectionError(
          'API error (${e.statusCode}): ${e.message}',
          userEmail: userEmail,
        );
      }
    } on AuthException catch (e) {
      return GscConnectionStatus.actionRequired(
        message: e.message,
        userEmail: userEmail,
      );
    } catch (e) {
      return GscConnectionStatus.connectionError(
        'Connection test failed: $e',
        userEmail: userEmail,
      );
    }
  }

  /// Disconnects account, signs out, and clears all stored tokens.
  Future<GscConnectionStatus> disconnect() async {
    try {
      await _signInAdapter.signOut();
    } catch (_) {}

    await _secureStorage.clearGscCredentials();

    await AppLogger.instance.info(
      'GoogleAuthService',
      'disconnected',
      'Cleared Google Search Console credentials and signed out.',
    );

    return GscConnectionStatus.notConfigured(
      message: 'Google Search Console disconnected.',
    );
  }
}
