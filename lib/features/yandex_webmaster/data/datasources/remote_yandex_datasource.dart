import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/yandex_host.dart';
import '../models/yandex_metric_model.dart';

/// Direct HTTPS client for official Yandex Webmaster API v4.
class RemoteYandexDatasource {
  final http.Client _client;
  final SecureStorageService _secureStorage;

  RemoteYandexDatasource({
    http.Client? client,
    SecureStorageService? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? SecureStorageService();

  static const String _baseUrl = 'https://api.webmaster.yandex.net/v4';
  static const Duration _timeout = Duration(seconds: 15);

  Future<String> _getToken() async {
    final token = await _secureStorage.getYandexOAuthToken();
    if (token == null || token.trim().isEmpty) {
      throw const AuthException('Yandex Webmaster OAuth token is not configured.');
    }
    return token.trim();
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'OAuth $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Retrieves the numeric user ID for the authenticated Yandex account.
  Future<int> getUserId([String? explicitToken]) async {
    final token = explicitToken ?? await _getToken();
    final url = Uri.parse('$_baseUrl/user/');

    try {
      final response = await _client.get(url, headers: _headers(token)).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final userId = data['user_id'] as int?;
        if (userId != null) return userId;
        throw const NetworkException('Invalid user profile response from Yandex API.');
      } else {
        _handleError('getUserId', response);
        return 0;
      }
    } on TimeoutException {
      throw const NetworkException('Connection to Yandex Webmaster timed out (15s).');
    } on SocketException catch (e) {
      throw NetworkException('Network connectivity failure: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP client error: ${e.message}');
    }
  }

  /// Lists verified and registered site properties (hosts) in Yandex Webmaster.
  Future<List<YandexHost>> getUserHosts({int? userId, String? explicitToken}) async {
    final token = explicitToken ?? await _getToken();
    final uid = userId ?? await getUserId(token);
    final url = Uri.parse('$_baseUrl/user/$uid/hosts/');

    try {
      final response = await _client.get(url, headers: _headers(token)).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final hosts = data['hosts'] as List<dynamic>? ?? [];
        return hosts
            .whereType<Map<String, dynamic>>()
            .map((h) => YandexHost.fromJson(h))
            .toList();
      } else {
        _handleError('getUserHosts', response);
        return [];
      }
    } on TimeoutException {
      throw const NetworkException('Connection to Yandex Webmaster timed out (15s).');
    } on SocketException catch (e) {
      throw NetworkException('Network connectivity failure: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP client error: ${e.message}');
    }
  }

  /// Ingests popular search queries for a verified host.
  Future<List<YandexMetricModel>> getPopularQueries({
    required int websiteId,
    required String hostId,
    int? userId,
    String? dateFrom,
    String? dateTo,
    int limit = 500,
  }) async {
    final token = await _getToken();
    final uid = userId ?? await getUserId(token);
    final encodedHost = Uri.encodeComponent(hostId);

    final queryParams = {
      'order_by': 'TOTAL_SHOWS',
      'query_indicator': [
        'TOTAL_SHOWS',
        'TOTAL_CLICKS',
        'AVG_SHOW_POSITION',
        'AVG_CLICK_POSITION',
      ],
      'limit': '$limit',
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
    };

    // Construct URI with repeating query_indicator keys
    final uri = Uri.parse('$_baseUrl/user/$uid/hosts/$encodedHost/search-queries/popular').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await _client.get(uri, headers: _headers(token)).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final queries = data['queries'] as List<dynamic>? ?? [];
        final now = DateTime.now();
        final metricDate = dateTo ??
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        return queries.map((q) {
          return YandexMetricModel.fromYandexJson(
            json: q as Map<String, dynamic>,
            websiteId: websiteId,
            metricDate: metricDate,
            syncedAt: now,
          );
        }).toList();
      } else {
        _handleError('getPopularQueries', response);
        return [];
      }
    } on TimeoutException {
      throw const NetworkException('Connection to Yandex Webmaster timed out (15s).');
    } on SocketException catch (e) {
      throw NetworkException('Network connectivity failure: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP client error: ${e.message}');
    }
  }

  void _handleError(String action, http.Response response) {
    if (response.statusCode == 401) {
      throw const AuthException(
        'Yandex OAuth authorization failed (401). Token may be expired or invalid.',
      );
    }
    if (response.statusCode == 403) {
      throw const AuthException(
        'Yandex API Forbidden (403). Ensure webmaster:verify and webmaster:hostinfo scopes are granted.',
      );
    }
    if (response.statusCode == 429) {
      throw const NetworkException(
        'Yandex Webmaster rate limit reached (429). Please retry after a brief delay.',
        statusCode: 429,
      );
    }
    throw NetworkException(
      'Yandex Webmaster API error [$action]: HTTP ${response.statusCode} - ${response.body}',
      statusCode: response.statusCode,
    );
  }
}
