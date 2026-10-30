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

class _MockBingRepository implements BingRepository {
  final BingPropertyMatchResult matchResult;
  final List<BingMetric> metrics;

  _MockBingRepository({required this.matchResult, this.metrics = const []});

  @override
  Future<List<BingMetric>> getMetrics(int websiteId, {int limit = 100}) async =>
      metrics;

  @override
  Future<List<String>> getVerifiedSites() async =>
      matchResult.availableProperties.map((p) => p.url).toList();

  @override
  Future<List<BingSiteProperty>> getSiteProperties() async =>
      matchResult.availableProperties;

  @override
  Future<BingPropertyMatchResult> checkPropertyStatus(
    String localDomain,
  ) async => matchResult;

  @override
  Future<int> syncMetricsFromApi({
    required int websiteId,
    required String siteUrl,
  }) async {
    if (!matchResult.isSyncAllowed) {
      throw ValidationFailure(
        matchResult.errorMessage ?? 'Sync not allowed for unverified property',
      );
    }
    return metrics.length;
  }
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  const dummyApiKey = 'test_bing_api_key_valid';
  const siteUrl = 'https://example.com/';

  group('1. Bing Model & Data Parsing Tests', () {
    test(
      'Correctly parses and scales Bing position values by factor of 10',
      () {
        final json = {
          'Query': 'flutter ranking tracker',
          'Clicks': 25,
          'Impressions': 500,
          'AvgImpressionPosition': 42, // scales to 4.2
          'AvgClickPosition': 38,
          'Date': '/Date(1672531199000)/',
        };

        final metric = BingMetricModel.fromBingJson(json, 1, DateTime.now());

        expect(metric.query, 'flutter ranking tracker');
        expect(metric.clicks, 25);
        expect(metric.impressions, 500);
        expect(metric.ctr, closeTo(0.05, 0.001));
        expect(metric.averagePosition, 4.2);
      },
    );

    test('Falls back to AvgClickPosition when AvgImpressionPosition is 0', () {
      final json = {
        'Query': 'best seo tool',
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
        'Query': 'unknown query',
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

      expect(() => ds.getUserSiteProperties(), throwsA(isA<AuthException>()));
      expect(
        () => ds.getQueryStats(websiteId: 1, siteUrl: siteUrl),
        throwsA(isA<AuthException>()),
      );
    });

    test('getUserSiteProperties parses rich properties successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/webmaster/api.svc/json/GetUserSites');
        expect(request.url.queryParameters['apikey'], dummyApiKey);

        return http.Response(
          json.encode({
            'd': [
              {'Url': 'https://example.com/', 'IsVerified': true},
              {'Url': 'http://unverified.org/', 'IsVerified': false},
            ],
          }),
          200,
        );
      });

      final ds = RemoteBingDatasource(
        client: mockClient,
        secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
      );

      final properties = await ds.getUserSiteProperties();
      expect(properties.length, 2);
      expect(properties[0].url, 'https://example.com/');
      expect(properties[0].isVerified, isTrue);
      expect(properties[1].url, 'http://unverified.org/');
      expect(properties[1].isVerified, isFalse);
    });

    test('GetQueryStats retrieves search performance data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/webmaster/api.svc/json/GetQueryStats');
        expect(request.url.queryParameters['siteUrl'], 'https://example.com/');

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
        siteUrl: 'https://example.com/',
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
                  {'Url': 'https://example.com/', 'IsVerified': true},
                ],
              }),
              200,
            );
          } else {
            expect(
              request.url.queryParameters['siteUrl'],
              'https://example.com/',
            );
            return http.Response(
              json.encode({
                'd': [
                  {
                    'Query': 'app seo',
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
          siteUrl: 'example.com',
        );

        expect(count, 1);
        expect(localDs.stored.length, 1);
        expect(localDs.stored.first.query, 'app seo');
        expect(localDs.stored.first.averagePosition, 1.2);
      },
    );

    test('Refuses to sync when website is unverified in Bing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'd': [
              {'Url': 'https://unverified.com/', 'IsVerified': false},
            ],
          }),
          200,
        );
      });

      final repo = BingRepositoryImpl(
        localDatasource: _FakeLocalBingDatasource(),
        remoteDatasource: RemoteBingDatasource(
          client: mockClient,
          secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
        ),
      );

      expect(
        () => repo.syncMetricsFromApi(websiteId: 1, siteUrl: 'unverified.com'),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('verification is still pending'),
          ),
        ),
      );
    });

    test('Refuses to sync when website is not found in Bing account', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'd': [
              {'Url': 'https://other-site.com/', 'IsVerified': true},
            ],
          }),
          200,
        );
      });

      final repo = BingRepositoryImpl(
        localDatasource: _FakeLocalBingDatasource(),
        remoteDatasource: RemoteBingDatasource(
          client: mockClient,
          secureStorage: _MockSecureStorage(initialKey: dummyApiKey),
        ),
      );

      expect(
        () =>
            repo.syncMetricsFromApi(websiteId: 1, siteUrl: 'missing-site.com'),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('was not found in your Bing Webmaster account'),
          ),
        ),
      );
    });
  });

  group('4. BingWebmasterView UI States and Sync Action Tests', () {
    final now = DateTime.now();
    final testSite = Website(
      id: 1,
      domain: 'example.com',
      label: 'Example Site',
      createdAt: now,
      updatedAt: now,
    );

    Widget buildTestHarness({
      required List<BingMetric> metrics,
      required BingPropertyMatchResult matchResult,
    }) {
      final mockRepo = _MockBingRepository(
        matchResult: matchResult,
        metrics: metrics,
      );

      return ProviderScope(
        overrides: [
          websitesProvider.overrideWith(
            () => _FakeWebsitesNotifier([testSite]),
          ),
          selectedWebsiteIdProvider.overrideWith(
            () => _TestSelectedWebsiteIdNotifier(1),
          ),
          bingRepositoryProvider.overrideWithValue(mockRepo),
          bingMetricsFutureProvider.overrideWith(
            (ref, websiteId) async => metrics,
          ),
          bingPropertyStatusProvider.overrideWith(
            (ref, domain) async => matchResult,
          ),
        ],
        child: const MaterialApp(home: BingWebmasterView()),
      );
    }

    testWidgets('Renders "Verified and Matched" badge for verified domain', (
      tester,
    ) async {
      const matchResult = BingPropertyMatchResult(
        status: BingVerificationStatus.verifiedAndMatched,
        matchedBingUrl: 'https://example.com/',
      );

      await tester.pumpWidget(
        buildTestHarness(metrics: [], matchResult: matchResult),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bing Webmaster Tools'), findsOneWidget);
      expect(find.text('Verified and Matched'), findsOneWidget);
      expect(
        find.text('Matched Property: https://example.com/'),
        findsOneWidget,
      );
      expect(find.text('No Bing Data Synced Yet'), findsOneWidget);
      expect(find.text('Sync with Bing'), findsOneWidget);
    });

    testWidgets(
      'Renders "Added Locally, Not Verified in Bing" for unverified site',
      (tester) async {
        const matchResult = BingPropertyMatchResult(
          status: BingVerificationStatus.locallyAddedNotVerified,
          matchedBingUrl: 'https://example.com/',
        );

        await tester.pumpWidget(
          buildTestHarness(metrics: [], matchResult: matchResult),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Added Locally, Not Verified in Bing'),
          findsOneWidget,
        );
        expect(find.text('Check Verification Status'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders "Bing Property Not Found" banner when site is absent',
      (tester) async {
        const matchResult = BingPropertyMatchResult(
          status: BingVerificationStatus.propertyNotFound,
          availableProperties: [
            BingSiteProperty(url: 'https://other-site.com/', isVerified: true),
          ],
        );

        await tester.pumpWidget(
          buildTestHarness(metrics: [], matchResult: matchResult),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bing Property Not Found'), findsOneWidget);
        expect(find.text('Refresh Bing Sites'), findsOneWidget);
      },
    );

    testWidgets('Renders populated query metrics list', (tester) async {
      const matchResult = BingPropertyMatchResult(
        status: BingVerificationStatus.verifiedAndMatched,
        matchedBingUrl: 'https://example.com/',
      );

      final sampleMetrics = [
        BingMetric(
          id: 1,
          websiteId: 1,
          query: 'best flutter analytics',
          metricDate: '2026-10-30',
          clicks: 14,
          impressions: 280,
          ctr: 0.05,
          averagePosition: 3.4,
          syncedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        buildTestHarness(metrics: sampleMetrics, matchResult: matchResult),
      );
      await tester.pumpAndSettle();

      expect(find.text('best flutter analytics'), findsOneWidget);
      expect(find.textContaining('14 clicks • 280 impr.'), findsOneWidget);
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
