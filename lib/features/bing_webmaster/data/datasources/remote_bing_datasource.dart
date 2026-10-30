import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../models/bing_metric_model.dart';

/// Direct HTTPS client for official Bing Webmaster Tools REST API.
class RemoteBingDatasource {
  final http.Client _client;
  final SecureStorageService _secureStorage;

  RemoteBingDatasource({
    http.Client? client,
    SecureStorageService? secureStorage,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? SecureStorageService();

  static const String _baseUrl = 'https://ssl.bing.com/webmaster/api.svc/json';

  /// Verifies API Key and retrieves user sites.
  Future<List<String>> getUserSites() async {
    final apiKey = await _secureStorage.getBingApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AuthException('Bing Webmaster API key is not configured.');
    }

    final url = Uri.parse('$_baseUrl/GetUserSites?apikey=$apiKey');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['d'] as List<dynamic>? ?? [];
      return list.map((e) => e['Url'] as String).where((s) => s.isNotEmpty).toList();
    } else {
      throw NetworkException(
        'Failed to query Bing Webmaster sites: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Fetches query stats for a verified site url.
  Future<List<BingMetricModel>> getQueryStats({
    required int websiteId,
    required String siteUrl,
  }) async {
    final apiKey = await _secureStorage.getBingApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AuthException('Bing Webmaster API key is not configured.');
    }

    final encodedSite = Uri.encodeComponent(siteUrl);
    final url = Uri.parse('$_baseUrl/GetQueryStats?siteUrl=$encodedSite&apikey=$apiKey');

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['d'] as List<dynamic>? ?? [];
      final now = DateTime.now();

      return list.map((item) {
        return BingMetricModel.fromBingJson(item as Map<String, dynamic>, websiteId, now);
      }).toList();
    } else {
      throw NetworkException(
        'Failed to query Bing Query Stats: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
