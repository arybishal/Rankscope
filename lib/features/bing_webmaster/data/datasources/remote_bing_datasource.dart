import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/logging/log_sanitizer.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/bing_site_property.dart';
import '../models/bing_metric_model.dart';

/// Direct HTTPS client for official Bing Webmaster Tools REST API.
class RemoteBingDatasource {
  final http.Client _client;
  final SecureStorageService _secureStorage;

  RemoteBingDatasource({
    http.Client? client,
    SecureStorageService? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? SecureStorageService();

  static const String _baseUrl = 'https://ssl.bing.com/webmaster/api.svc/json';
  static const Duration _timeout = Duration(seconds: 15);

  /// Retrieves all site properties registered in Bing Webmaster Tools with verification status.
  Future<List<BingSiteProperty>> getUserSiteProperties() async {
    final apiKey = await _secureStorage.getBingApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AuthException('Bing Webmaster API key is not configured.');
    }

    final sanitizedKey = apiKey.trim();
    final url = Uri.parse('$_baseUrl/GetUserSites?apikey=$sanitizedKey');

    try {
      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['d'] as List<dynamic>? ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => BingSiteProperty.fromJson(e))
            .where((p) => p.url.isNotEmpty)
            .toList();
      } else {
        _handleErrorResponse('GetUserSites', response);
        return [];
      }
    } on TimeoutException {
      throw const NetworkException(
        'Connection to Bing Webmaster timed out (15s).',
      );
    } on SocketException catch (e) {
      throw NetworkException('Network connectivity failure: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP client error: ${e.message}');
    }
  }

  /// Verifies API Key and retrieves user site URLs.
  Future<List<String>> getUserSites() async {
    final properties = await getUserSiteProperties();
    return properties.map((p) => p.url).toList();
  }

  /// Fetches query stats for a verified site url.
  Future<List<BingMetricModel>> getQueryStats({
    required int websiteId,
    required String siteUrl,
  }) async {
    final apiKey = await _secureStorage.getBingApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AuthException('Bing Webmaster API key is not configured.');
    }

    final sanitizedKey = apiKey.trim();
    final encodedSite = Uri.encodeComponent(siteUrl);
    final url = Uri.parse(
      '$_baseUrl/GetQueryStats?siteUrl=$encodedSite&apikey=$sanitizedKey',
    );

    try {
      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['d'] as List<dynamic>? ?? [];
        final now = DateTime.now();

        return list.map((item) {
          return BingMetricModel.fromBingJson(
            item as Map<String, dynamic>,
            websiteId,
            now,
          );
        }).toList();
      } else {
        _handleErrorResponse('GetQueryStats', response);
        return [];
      }
    } on TimeoutException {
      throw const NetworkException(
        'Connection to Bing Webmaster timed out (15s).',
      );
    } on SocketException catch (e) {
      throw NetworkException('Network connectivity failure: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP client error: ${e.message}');
    }
  }

  void _handleErrorResponse(String endpoint, http.Response response) {
    String detail = 'HTTP ${response.statusCode}';
    try {
      final errorJson = json.decode(response.body);
      if (errorJson is Map<String, dynamic>) {
        if (errorJson.containsKey('Message')) {
          detail = errorJson['Message'].toString();
        } else if (errorJson.containsKey('d')) {
          detail = errorJson['d'].toString();
        }
      } else if (response.body.isNotEmpty) {
        detail = response.body;
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        detail = response.body;
      }
    }

    // Redact any secrets or echoed credentials
    final sanitizedMessage = LogSanitizer.sanitize(
      'Bing Webmaster $endpoint failed: $detail',
    );

    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      throw AuthException(sanitizedMessage);
    }

    throw NetworkException(sanitizedMessage, statusCode: response.statusCode);
  }
}
