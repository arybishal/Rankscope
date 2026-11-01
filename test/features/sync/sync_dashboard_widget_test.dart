import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/database/app_database.dart';
import 'package:rankscope/features/sync/data/datasources/sync_history_datasource.dart';
import 'package:rankscope/features/sync/presentation/views/sync_history_view.dart';
import 'package:rankscope/features/sync/presentation/widgets/sync_dashboard_card.dart';

import '../../test_helper.dart';

Widget buildTestWidget({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  group('Sync UI Widgets Tests', () {
    late AppDatabase dbManager;

    setUp(() async {
      dbManager = AppDatabase.instance;
      await dbManager.initCustom(inMemoryDatabasePath);
      setupMockSecureStorage();
    });

    tearDown(() async {
      await dbManager.close();
    });

    testWidgets('SyncDashboardCard renders all primary elements properly', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: const SyncDashboardCard()));
      await tester.pumpAndSettle();

      expect(find.text('Engine Sync Dashboard'), findsOneWidget);
      expect(find.text('Unified GSC, Bing & Yandex background sync'), findsOneWidget);
      expect(find.text('Sync All Now'), findsOneWidget);
      expect(find.text('Next Scheduled'), findsOneWidget);
      expect(find.text('Last Sync'), findsOneWidget);
      expect(find.text('Audit History Log'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('SyncHistoryView displays filter chips and empty state when empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncHistoryListProvider(null).overrideWith((ref) async => <SyncHistoryRecord>[]),
          ],
          child: const MaterialApp(
            home: SyncHistoryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync Audit History'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Bing'), findsOneWidget);
      expect(find.text('Yandex'), findsOneWidget);
      expect(find.text('No Sync History'), findsOneWidget);
    });

    testWidgets('SyncHistoryView renders audit record cards with duration and status', (tester) async {
      final now = DateTime.now();
      final testRecord = SyncHistoryRecord(
        websiteId: 1,
        websiteDomain: 'mytestsite.com',
        searchEngine: 'Google',
        startedAt: now.subtract(const Duration(seconds: 3)),
        completedAt: now,
        status: 'success',
        recordsRetrieved: 42,
        matchedKeywords: 9,
        triggerType: 'auto',
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncHistoryListProvider(null).overrideWith((ref) async => [testRecord]),
          ],
          child: const MaterialApp(
            home: SyncHistoryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('mytestsite.com'), findsOneWidget);
      expect(find.text('Google'), findsWidgets);
      expect(find.text('AUTO'), findsOneWidget);
      expect(find.textContaining('42 queries'), findsOneWidget);
    });
  });
}
