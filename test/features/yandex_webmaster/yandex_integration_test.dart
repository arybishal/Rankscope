import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rankscope/core/constants/database_constants.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/core/errors/exceptions.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/yandex_webmaster/data/datasources/local_yandex_datasource.dart';
import 'package:rankscope/features/yandex_webmaster/data/datasources/remote_yandex_datasource.dart';
import 'package:rankscope/features/yandex_webmaster/data/models/yandex_metric_model.dart';
import 'package:rankscope/features/yandex_webmaster/domain/entities/yandex_host.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_helper.dart';

class _MockSecureStorage extends SecureStorageService {
  String? _yandexToken;
  _MockSecureStorage({String? initialToken}) : _yandexToken = initialToken;

  @override
  Future<String?> getYandexOAuthToken() async => _yandexToken;

  @override
  Future<void> saveYandexOAuthToken(String token) async => _yandexToken = token;

  @override
  Future<void> clearYandexCredentials() async => _yandexToken = null;
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
    setupMockSecureStorage();
  });

  group('1. Yandex Entity & Model JSON Parsing Tests', () {
    test('Parses YandexHost from API response correctly', () {
      final jsonHost = {
        'host_id': 'https:example.com:443',
        'ascii_host_url': 'https://example.com/',
        'unicode_host_url': 'https://example.com/',
        'verified': true,
        'main_mirror': null,
      };

      final host = YandexHost.fromJson(jsonHost);
      expect(host.hostId, equals('https:example.com:443'));
      expect(host.asciiHostUrl, equals('https://example.com/'));
      expect(host.verified, isTrue);
      expect(host.displayName, equals('https://example.com/'));
    });

    test('Parses YandexMetricModel with indicator list correctly', () {
      final queryJson = {
        'query_text': 'best seo tracker',
        'indicators': {
          'TOTAL_SHOWS': 1500,
          'TOTAL_CLICKS': 75,
          'AVG_SHOW_POSITION': 4.2,
          'AVG_CLICK_POSITION': 3.8,
        },
      };

      final now = DateTime.now();
      final model = YandexMetricModel.fromYandexJson(
        json: queryJson,
        websiteId: 10,
        metricDate: '2026-10-31',
        syncedAt: now,
      );

      expect(model.websiteId, equals(10));
      expect(model.query, equals('best seo tracker'));
      expect(model.impressions, equals(1500));
      expect(model.clicks, equals(75));
      expect(model.averagePosition, equals(4.2));
      expect(model.averageClickPosition, equals(3.8));
      expect(model.ctr, closeTo(0.05, 0.001));
      expect(model.metricDate, equals('2026-10-31'));
    });

    test('Handles null or missing indicators safely without crash', () {
      final emptyJson = {
        'query_text': 'unranked keyword',
        'indicators': <String, dynamic>{},
      };

      final now = DateTime.now();
      final model = YandexMetricModel.fromYandexJson(
        json: emptyJson,
        websiteId: 10,
        metricDate: '2026-10-31',
        syncedAt: now,
      );

      expect(model.impressions, equals(0));
      expect(model.clicks, equals(0));
      expect(model.averagePosition, equals(0.0));
      expect(model.averageClickPosition, isNull);
      expect(model.ctr, equals(0.0));
    });
  });

  group('2. RemoteYandexDatasource Network Tests', () {
    test('getUserId succeeds on 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/v4/user/'));
        expect(request.headers['Authorization'], equals('OAuth y0_test_token'));
        return http.Response(
          json.encode({'user_id': 987654321}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final storage = _MockSecureStorage(initialToken: 'y0_test_token');
      final datasource = RemoteYandexDatasource(
        client: mockClient,
        secureStorage: storage,
      );

      final uid = await datasource.getUserId('y0_test_token');
      expect(uid, equals(987654321));
    });

    test('getUserHosts fetches and parses hosts array', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v4/user/') {
          return http.Response(json.encode({'user_id': 12345}), 200);
        }
        if (request.url.path == '/v4/user/12345/hosts/') {
          return http.Response(
            json.encode({
              'hosts': [
                {
                  'host_id': 'https:rankscope.dev:443',
                  'ascii_host_url': 'https://rankscope.dev/',
                  'verified': true,
                },
                {
                  'host_id': 'http:unverified.dev:80',
                  'ascii_host_url': 'http://unverified.dev/',
                  'verified': false,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final storage = _MockSecureStorage(initialToken: 'y0_valid_token');
      final datasource = RemoteYandexDatasource(
        client: mockClient,
        secureStorage: storage,
      );

      final hosts = await datasource.getUserHosts(userId: 12345);
      expect(hosts.length, equals(2));
      expect(hosts.first.hostId, equals('https:rankscope.dev:443'));
      expect(hosts.first.verified, isTrue);
      expect(hosts.last.verified, isFalse);
    });

    test('Throws AuthException on 401 Unauthorized', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'error_code': 'UNAUTHORIZED', 'message': 'Invalid token'}),
          401,
        );
      });

      final storage = _MockSecureStorage(initialToken: 'expired_token');
      final datasource = RemoteYandexDatasource(
        client: mockClient,
        secureStorage: storage,
      );

      expect(
        () => datasource.getUserId('expired_token'),
        throwsA(isA<AuthException>()),
      );
    });

    test('Throws NetworkException on 429 Rate Limit', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Quota exceeded', 429);
      });

      final storage = _MockSecureStorage(initialToken: 'valid_token');
      final datasource = RemoteYandexDatasource(
        client: mockClient,
        secureStorage: storage,
      );

      expect(
        () => datasource.getUserHosts(userId: 12345),
        throwsA(
          predicate<NetworkException>((e) => e.statusCode == 429),
        ),
      );
    });
  });

  group('3. SQLite M005 Migration & Local Data Tests', () {
    late Database db;

    setUp(() async {
      db = await AppDatabase.instance.initCustom(inMemoryDatabasePath);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('M005 adds yandex columns to websites and keywords and creates yandex_search_analytics', () async {
      // 1. Verify yandex_host_id column in websites
      final websiteCols = await db.rawQuery('PRAGMA table_info(websites);');
      final websiteColNames = websiteCols.map((c) => c['name'] as String).toSet();
      expect(websiteColNames.contains('yandex_host_id'), isTrue);

      // 2. Verify yandex performance columns in keywords
      final kwCols = await db.rawQuery('PRAGMA table_info(keywords);');
      final kwColNames = kwCols.map((c) => c['name'] as String).toSet();
      expect(kwColNames.contains('yandex_average_position'), isTrue);
      expect(kwColNames.contains('yandex_ranking_url'), isTrue);
      expect(kwColNames.contains('yandex_impressions'), isTrue);
      expect(kwColNames.contains('yandex_clicks'), isTrue);
      expect(kwColNames.contains('yandex_ctr'), isTrue);
      expect(kwColNames.contains('yandex_synced_at'), isTrue);
      expect(kwColNames.contains('yandex_position'), isTrue);
      expect(kwColNames.contains('yandex_delta'), isTrue);

      // 3. Verify yandex_search_analytics table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='yandex_search_analytics';",
      );
      expect(tables.isNotEmpty, isTrue);
    });

    test('LocalYandexDatasource batch upsert and aggregate calculations', () async {
      final now = DateTime.now();

      // Create test website
      final websiteId = await db.insert(DatabaseConstants.tableWebsites, {
        'domain': 'mysite.com',
        'label': 'My Site',
        'is_competitor': 0,
        'yandex_host_id': 'https:mysite.com:443',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      final localDatasource = LocalYandexDatasource();

      final metricsToInsert = [
        YandexMetricModel(
          websiteId: websiteId,
          query: 'flutter rank tracking',
          impressions: 500,
          clicks: 50,
          averagePosition: 3.5,
          averageClickPosition: 2.8,
          ctr: 0.10,
          metricDate: '2026-10-31',
          syncedAt: now,
        ),
        YandexMetricModel(
          websiteId: websiteId,
          query: 'seo audit android',
          impressions: 200,
          clicks: 10,
          averagePosition: 8.0,
          averageClickPosition: 6.5,
          ctr: 0.05,
          metricDate: '2026-10-31',
          syncedAt: now,
        ),
      ];

      // Upsert batch
      final insertedCount = await localDatasource.upsertMetricsBatch(metricsToInsert);
      expect(insertedCount, equals(2));

      // Query metrics
      final retrieved = await localDatasource.getMetrics(websiteId);
      expect(retrieved.length, equals(2));
      expect(retrieved.first.query, equals('flutter rank tracking'));

      // Compute aggregates
      final aggregates = await localDatasource.getAggregates(websiteId);
      expect(aggregates['total_impressions'], equals(700));
      expect(aggregates['total_clicks'], equals(60));
      expect(aggregates['average_position'], isNotNull);
      expect(aggregates['average_ctr'], closeTo(60 / 700, 0.001));
    });
  });

  group('4. Keyword Domain Entity Yandex Dimension Tests', () {
    test('Keyword returns correct position and delta for Yandex engine', () {
      final now = DateTime.now();
      final kw = Keyword(
        id: 1,
        websiteId: 10,
        keywordText: 'yandex rank tracker',
        googlePosition: 5,
        bingPosition: 8,
        yandexPosition: 3,
        yandexPreviousPosition: 7,
        yandexDelta: 4,
        yandexAveragePosition: 3.2,
        yandexImpressions: 450,
        yandexClicks: 32,
        yandexRankingUrl: 'https://mysite.com/tracker',
        createdAt: now,
      );

      // Verify positionFor engine dispatch
      expect(kw.positionFor('Google'), equals(5));
      expect(kw.positionFor('Bing'), equals(8));
      expect(kw.positionFor('Yandex'), equals(3));
      expect(kw.positionFor('All'), equals(5));

      // Verify delta computation (+4 rank improvement from 7 to 3)
      expect(kw.deltaFor('Yandex'), equals(4));

      // Verify impressions and clicks dispatch
      expect(kw.impressionsFor('Yandex'), equals(450));
      expect(kw.clicksFor('Yandex'), equals(32));
      expect(kw.averagePositionFor('Yandex'), equals(3.2));
      expect(kw.performanceRankingUrlFor('Yandex'), equals('https://mysite.com/tracker'));
      expect(kw.hasYandexData, isTrue);
    });
  });
}
