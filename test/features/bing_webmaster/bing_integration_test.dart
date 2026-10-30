import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rankscope/core/errors/exceptions.dart';
import 'package:rankscope/core/errors/failures.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/features/bing_webmaster/data/datasources/local_bing_datasource.dart';
import 'package:rankscope/features/bing_webmaster/data/datasources/remote_bing_datasource.dart';
import 'package:rankscope/features/bing_webmaster/data/models/bing_metric_model.dart';
import 'package:rankscope/features/bing_webmaster/data/repositories/bing_repository_impl.dart';
import 'package:rankscope/features/bing_webmaster/presentation/controllers/bing_controller.dart';
import 'package:rankscope/features/bing_webmaster/presentation/views/bing_webmaster_view.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';

import '../../test_helper.dart';

class _MockSecureStorage extends SecureStorageService {
  String? _bingKey;
  _MockSecureStorage({String? initialKey}) : _bingKey = initialKey;

  @override
  Future<String?> getBingApiKey() async => _bingKey;

  @override
  Future<void> saveBingApiKey(String apiKey) async => _bingKey = apiKey;

  @override
  Future<void> clearBingCredentials() async => _bingKey = null;
}

class _FakeLocalBingDatasource extends LocalBingDatasource {
  final List<BingMetricModel> stored = [];

  @override
  Future<int> upsertMetricsBatch(List<BingMetricModel> models) async {
    stored.clear();
    stored.addAll(models);
    return models.length;
  }

  @override
  Future<List<BingMetricModel>> getMetrics(
    int websiteId, {
    int limit = 100,
  }) async {
    return stored.where((m) => m.websiteId == websiteId).toList();
  }
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  const dummyApiKey = 'test_bing_api_key_valid';
  const siteUrl = 'https://techinfonepal.com/';

  group('1. Bing Model & Data Parsing Tests', () {
    test(
      'Correctly parses and scales Bing position values by factor of 10',
      () {
        final json = {
          'Query': 'nepal tech news',
          'Clicks': 25,
          'Impressions': 500,
          'AvgImpressionPosition': 42, // should scale to 4.2
          'AvgClickPosition': 38,
          'Date': '/Date(1672531199000)/',
        };

        final metric = BingMetricModel.fromBingJson(json, 1, DateTime.now());

        expect(metric.query, 'nepal tech news');
        expect(metric.clicks, 25);
        expect(metric.impressions, 500);
        expect(metric.ctr, closeTo(0.05, 0.001));
        expect(metric.averagePosition, 4.2);
      },
    );

    test('Falls back to AvgClickPosition when AvgImpressionPosition is 0', () {
      final json = {
        'Query': 'flutter ranking tracker',
        'Clicks': 5,
        'Impressions': 50,
        'AvgImpressionPosition': 0,
        'AvgClickPosition': 15, // scales to 1.5
      };

      final metric = BingMetricModel.fromBingJson(json, 1, DateTime.now());
      expect(metric.averagePosition, 1.5);
    });

    test('Handles zero clicks and zero position gracefully', () {
      final json = {
        'Query': 'unknown search',
        'Clicks': 0,
        'Impressions': 0,
        'AvgImpressionPosition': -1,
        'AvgClickPosition': 0,
      };

      final metric = BingMetricModel.fromBingJson(json, 1, DateTime.now());
      expect(metric.clicks, 0);
      expect(metric.impressions, 0);
      expect(metric.ctr, 0.0);
      expect(metric.averagePosition, 0.0);
    });
  });

  group('2. RemoteBingDatasource API Communication Tests', () {
    test('Throws AuthException when Bing API key is not configured', () async {
      final ds = RemoteBingDatasource(
        secureStorage: _MockSecureStorage(initialKey: null),
      );

      expect(() => ds.getUserSites(), throwsA(isA<AuthException>()));
      expect(
        () => ds.getQueryStats(websiteId: 1, siteUrl: siteUrl),
        throwsA(isA<AuthException>()),
      );
    });

    test('GetUserSites parses verified site URLs successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/webmaster/api.svc/json/GetUserSites');
        expect(request.url.queryParameters['apikey'], dummyApiKey);

        return http.Response(
          json.encode({
            'd': [
              {'Url': 'https://techinfonepal.com/', 'IsVerified': true},
              {'Url': 'https://rankscope.org/', 'IsVerified': true},
            ],
          }),
          200,
        );
      });

      final ds = RemoteBingDatasource(
        client: mockClient,
        secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
      );

      final sites = await ds.getUserSites();
      expect(sites, ['https://techinfonepal.com/', 'https://rankscope.org/']);
    });

    test('GetQueryStats retrieves search performance data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/webmaster/api.svc/json/GetQueryStats');
        expect(
          request.url.queryParameters['siteUrl'],
          'https://techinfonepal.com/',
        );

        return http.Response(
          json.encode({
            'd': [
              {
                'Query': 'rankscope seo',
                'Clicks': 10,
                'Impressions': 100,
                'AvgImpressionPosition': 25,
                'Date': '/Date(1672531199000)/',
              },
            ],
          }),
          200,
        );
      });

      final ds = RemoteBingDatasource(
        client: mockClient,
        secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
      );

      final stats = await ds.getQueryStats(
        websiteId: 1,
        siteUrl: 'https://techinfonepal.com/',
      );

      expect(stats.length, 1);
      expect(stats.first.query, 'rankscope seo');
      expect(stats.first.clicks, 10);
      expect(stats.first.impressions, 100);
      expect(stats.first.averagePosition, 2.5);
    });

    test(
      'Handles invalid API key (400 / 401) without leaking credentials',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({'ErrorCode': 2, 'Message': 'ApiKey is invalid'}),
            400,
          );
        });

        final ds = RemoteBingDatasource(
          client: mockClient,
          secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
        );

        try {
          await ds.getUserSites();
          fail('Should have thrown AuthException');
        } on AuthException catch (e) {
          expect(e.message, contains('ApiKey is invalid'));
          expect(e.message.contains(dummyApiKey), isFalse);
        }
      },
    );

    test('Handles network connectivity failure gracefully', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup ssl.bing.com');
      });

      final ds = RemoteBingDatasource(
        client: mockClient,
        secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
      );

      expect(
        () => ds.getUserSites(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('Failed host lookup'),
          ),
        ),
      );
    });
  });

  group('3. BingRepositoryImpl Site Mapping & Sync Flow', () {
    test(
      'Maps raw domain to canonical verified Bing site URL and syncs data',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('GetUserSites')) {
            return http.Response(
              json.encode({
                'd': [
                  {'Url': 'https://techinfonepal.com/', 'IsVerified': true},
                ],
              }),
              200,
            );
          } else {
            expect(
              request.url.queryParameters['siteUrl'],
              'https://techinfonepal.com/',
            );
            return http.Response(
              json.encode({
                'd': [
                  {
                    'Query': 'tech info',
                    'Clicks': 8,
                    'Impressions': 80,
                    'AvgImpressionPosition': 12,
                  },
                ],
              }),
              200,
            );
          }
        });

        final localDs = _FakeLocalBingDatasource();
        final remoteDs = RemoteBingDatasource(
          client: mockClient,
          secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
        );

        final repo = BingRepositoryImpl(
          localDatasource: localDs,
          remoteDatasource: remoteDs,
        );

        // Pass domain without protocol or trailing slash
        final count = await repo.syncMetricsFromApi(
          websiteId: 42,
          siteUrl: 'techinfonepal.com',
        );

        expect(count, 1);
        expect(localDs.stored.length, 1);
        expect(localDs.stored.first.query, 'tech info');
        expect(localDs.stored.first.averagePosition, 1.2);
      },
    );

    test('Returns 0 when Bing returns empty stats list', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('GetUserSites')) {
          return http.Response(
            json.encode({
              'd': [
                {'Url': 'https://empty-domain.com/', 'IsVerified': true},
              ],
            }),
            200,
          );
        }
        return http.Response(json.encode({'d': []}), 200);
      });

      final localDs = _FakeLocalBingDatasource();
      final remoteDs = RemoteBingDatasource(
        client: mockClient,
        secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
      );

      final repo = BingRepositoryImpl(
        localDatasource: localDs,
        remoteDatasource: remoteDs,
      );

      final count = await repo.syncMetricsFromApi(
        websiteId: 1,
        siteUrl: 'empty-domain.com',
      );

      expect(count, 0);
      expect(localDs.stored, isEmpty);
    });

    test('Catches AuthException and returns AuthenticationFailure', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final repo = BingRepositoryImpl(
        localDatasource: _FakeLocalBingDatasource(),
        remoteDatasource: RemoteBingDatasource(
          client: mockClient,
          secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
        ),
      );

      expect(
        () => repo.getVerifiedSites(),
        throwsA(isA<AuthenticationFailure>()),
      );
    });
  });

  group('4. BingWebmasterView UI States and Sync Action Tests', () {
    final now = DateTime.now();
    final testSite = Website(
      id: 1,
      domain: 'techinfonepal.com',
      label: 'Techinfo Nepal',
      createdAt: now,
      updatedAt: now,
    );

    Widget buildTestHarness({
      required List<BingMetric> metrics,
      BingRepository? customRepo,
    }) {
      return ProviderScope(
        overrides: [
          websitesProvider.overrideWith(
            () => _FakeWebsitesNotifier([testSite]),
          ),
          selectedWebsiteIdProvider.overrideWith(
            () => _TestSelectedWebsiteIdNotifier(1),
          ),
          bingMetricsFutureProvider.overrideWith(
            (ref, websiteId) async => metrics,
          ),
          if (customRepo != null)
            bingRepositoryProvider.overrideWithValue(customRepo),
        ],
        child: const MaterialApp(home: BingWebmasterView()),
      );
    }

    testWidgets('Renders empty data state with "Sync with Bing" button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestHarness(metrics: []));
      await tester.pumpAndSettle();

      expect(find.text('Bing Webmaster Tools'), findsOneWidget);
      expect(find.text('No Bing Data Synced Yet'), findsOneWidget);
      expect(find.text('Sync with Bing'), findsOneWidget);
    });

    testWidgets('Renders populated query metrics list', (tester) async {
      final sampleMetrics = [
        BingMetric(
          id: 1,
          websiteId: 1,
          query: 'nepal tech gadgets',
          metricDate: '2026-10-30',
          clicks: 14,
          impressions: 280,
          ctr: 0.05,
          averagePosition: 3.4,
          syncedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestHarness(metrics: sampleMetrics));
      await tester.pumpAndSettle();

      expect(find.text('nepal tech gadgets'), findsOneWidget);
      expect(find.text('14 clicks • 280 impr.'), findsOneWidget);
      expect(find.text('Avg #3.4'), findsOneWidget);
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
