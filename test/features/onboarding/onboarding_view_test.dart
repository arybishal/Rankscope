import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rankscope/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:rankscope/features/settings/presentation/views/settings_view.dart';

import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupSqfliteFfi();
  });

  setUp(() {
    setupMockSecureStorage();
  });

  Widget buildTestApp({
    String initialLocation = '/onboarding',
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) {
            final isRevisit = state.uri.queryParameters['revisit'] == 'true';
            return OnboardingView(isRevisit: isRevisit);
          },
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const Scaffold(
            body: Text('Dashboard Screen Loaded'),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsView(),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('OnboardingView Feature Slider Tests', () {
    testWidgets('Renders first slide with Multi-Website feature highlights', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Brand Title
      expect(find.text('RankScope'), findsOneWidget);
      expect(find.text('Skip Tour'), findsOneWidget);

      // Slide 1 Content
      expect(find.text('Multi-Website Intelligence'), findsOneWidget);
      expect(find.text('Manage Your Domains & Competitors'), findsOneWidget);
      expect(find.text('Multiple Property Support'), findsOneWidget);
      expect(find.text('Dynamic Property Switcher'), findsOneWidget);
      expect(find.text('Competitor Tracking'), findsOneWidget);

      // Next Button
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Swipes through all 4 feature slides and displays developer info', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Advance to Slide 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Keyword Rank & Target URL Audit'), findsOneWidget);
      expect(find.text('Landing Page Match Audit'), findsOneWidget);
      expect(find.text('Cannibalization Detection'), findsOneWidget);

      // Advance to Slide 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Search Console & Bing Sync'), findsOneWidget);
      expect(find.text('Live Query Data Sync'), findsOneWidget);
      expect(find.text('Android KeyStore Security'), findsOneWidget);

      // Advance to Slide 4
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('100% Device-Only Privacy'), findsOneWidget);
      expect(find.text('Local-First SQLite Engine'), findsOneWidget);
      expect(find.text('AES-256-GCM Encrypted Backups'), findsOneWidget);

      // Verify Developer & Author URL Mention
      expect(find.text('Developer: '), findsOneWidget);
      expect(find.text('.com.npAryal'), findsOneWidget);
      expect(find.text('author url: '), findsOneWidget);
      expect(find.text('bishalaryal.com.np'), findsOneWidget);

      // Final CTA
      expect(find.text('Get Started with RankScope'), findsOneWidget);
    });

    testWidgets('Tapping author url triggers clipboard copy snackbar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Advance to final slide
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Ensure author URL is visible on screen
      await tester.ensureVisible(find.text('bishalaryal.com.np'));
      await tester.pumpAndSettle();

      // Tap on author URL
      await tester.tap(find.text('bishalaryal.com.np'));
      await tester.pump();

      expect(find.text('Author URL copied: bishalaryal.com.np'), findsOneWidget);
    });

    testWidgets('Tapping Skip navigates directly to dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Skip Tour'), findsOneWidget);
      await tester.tap(find.text('Skip Tour'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Screen Loaded'), findsOneWidget);
    });

    testWidgets('Tapping Get Started on final slide navigates to dashboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Go to final slide
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap Get Started
      await tester.tap(find.text('Get Started with RankScope'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Screen Loaded'), findsOneWidget);
    });

    testWidgets('Revisit mode displays back button and Finish Tour', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(initialLocation: '/onboarding?revisit=true'));
      await tester.pumpAndSettle();

      // In revisit mode, back button exists and Skip Tour is hidden
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Skip Tour'), findsNothing);

      // Go to final slide
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Finish Tour'), findsOneWidget);
    });
  });

  group('SettingsView Developer & Author Attribution Tests', () {
    testWidgets('SettingsView displays developer and author url in About section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(initialLocation: '/settings'));
      await tester.pumpAndSettle();

      // Scroll to bottom
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('ABOUT & DEVELOPER'), findsOneWidget);
      expect(find.text('Developer: '), findsOneWidget);
      expect(find.text('Bishal Aryal'), findsOneWidget);
      expect(find.text('Author Website: '), findsOneWidget);
      expect(find.text('https://bishalaryal.com.np'), findsOneWidget);
      expect(find.text('Replay App Feature Tour'), findsOneWidget);
    });
  });
}
