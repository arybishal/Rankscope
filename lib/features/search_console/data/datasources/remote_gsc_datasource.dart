import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../models/gsc_metric_model.dart';

/// Direct HTTPS client for official Google Search Console REST API v3.
class RemoteGscDatasource {
  final http.Client _client;
  final SecureStorageService _secureStorage;

  RemoteGscDatasource({
    http.Client? client,
    SecureStorageService? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? SecureStorageService();

  static const String _baseUrl = 'https://www.googleapis.com/webmasters/v3';

  /// Lists verified site properties for authorized Google account.
  Future<List<String>> listVerifiedSites() async {
    final token = await _getValidAccessToken();
    final url = Uri.parse('$_baseUrl/sites');

    final response = await _client.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final siteEntries = data['siteEntry'] as List<dynamic>? ?? [];
      return siteEntries
          .map((e) => e['siteUrl'] as String)
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      throw NetworkException(
        'Failed to query Google Search Console sites: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Ingests search analytics query metrics for a date range with optional filters.
  Future<List<GscMetricModel>> querySearchAnalytics({
    required int websiteId,
    required String siteUrl,
    required String startDate, // YYYY-MM-DD
    required String endDate, // YYYY-MM-DD
    int rowLimit = 5000,
    String? country,
    String? device,
    String? searchType,
  }) async {
    final token = await _getValidAccessToken();
    final encodedSite = Uri.encodeComponent(siteUrl);
    final url = Uri.parse('$_baseUrl/sites/$encodedSite/searchAnalytics/query');

    final Map<String, dynamic> requestPayload = {
      'startDate': startDate,
      'endDate': endDate,
      'dimensions': ['date', 'query', 'page', 'country', 'device'],
      'rowLimit': rowLimit,
    };

    if (searchType != null && searchType.isNotEmpty) {
      requestPayload['type'] = searchType.toLowerCase();
    }

    final List<Map<String, dynamic>> filters = [];
    if (country != null &&
        country.isNotEmpty &&
        country.toUpperCase() != 'GLOBAL' &&
        country.toLowerCase() != 'all') {
      filters.add({
        'dimension': 'country',
        'operator': 'equals',
        'expression': country.toLowerCase(),
      });
    }
    if (device != null &&
        device.isNotEmpty &&
        device.toLowerCase() != 'all') {
      filters.add({
        'dimension': 'device',
        'operator': 'equals',
        'expression': device.toUpperCase(),
      });
    }
    if (filters.isNotEmpty) {
      requestPayload['dimensionFilterGroups'] = [
        {'filters': filters}
      ];
    }

    final body = json.encode(requestPayload);

    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final rows = data['rows'] as List<dynamic>? ?? [];
      final now = DateTime.now();

      return rows.map((r) {
        final rowMap = r as Map<String, dynamic>;
        final keys = rowMap['keys'] as List<dynamic>? ?? [];
        return GscMetricModel.fromGscRow(
          websiteId: websiteId,
          keys: keys,
          clicks: rowMap['clicks'] as int? ?? 0,
          impressions: rowMap['impressions'] as int? ?? 0,
          ctr: (rowMap['ctr'] as num?)?.toDouble() ?? 0.0,
          position: (rowMap['position'] as num?)?.toDouble() ?? 0.0,
          syncedAt: now,
        );
      }).toList();
    } else {
      throw NetworkException(
        'Failed to fetch GSC search analytics: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  Future<String> _getValidAccessToken() async {
    String? token = await _secureStorage.getGscAccessToken();
    final isExpired = await _secureStorage.isGscAccessTokenExpired();

    if (token == null || isExpired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed != null && refreshed.isNotEmpty) {
        return refreshed;
      }
    }

    if (token != null && token.isNotEmpty) {
      return token;
    }

    throw const AuthException(
      'No valid Google Search Console authentication token available.',
    );
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _secureStorage.getGscRefreshToken();
    final clientId = await _secureStorage.getGscClientId();

    if (refreshToken == null || clientId == null) {
      return null;
    }

    final url = Uri.parse('https://oauth2.googleapis.com/token');
    final response = await _client.post(
      url,
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final expiresIn = data['expires_in'] as int? ?? 3600;
      final expiryEpochMs =
          DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

      await _secureStorage.saveGscAccessToken(newAccessToken, expiryEpochMs);
      return newAccessToken;
    }

    return null;
  }
}
