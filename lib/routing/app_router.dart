import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analysis/presentation/views/analysis_view.dart';
import '../features/bing_webmaster/presentation/views/bing_webmaster_view.dart';
import '../features/dashboard/presentation/views/dashboard_view.dart';
import '../features/keywords/presentation/views/keywords_list_view.dart';
import '../features/manual_tracking/presentation/views/manual_tracking_view.dart';
import '../features/onboarding/presentation/views/onboarding_view.dart';
import '../features/search_console/presentation/views/search_console_view.dart';
import '../features/search_engines/presentation/views/search_engines_view.dart';
import '../features/settings/presentation/views/logs_view.dart';
import '../features/settings/presentation/views/settings_view.dart';
import '../features/sync/presentation/views/sync_history_view.dart';
import '../features/websites/presentation/views/websites_management_view.dart';
import '../features/yandex_webmaster/presentation/views/yandex_webmaster_view.dart';
import 'navigation_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Factory to generate declarative GoRouter routing tree for RankScope.
GoRouter createAppRouter({String initialLocation = '/dashboard'}) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final isRevisit = state.uri.queryParameters['revisit'] == 'true';
        return OnboardingView(isRevisit: isRevisit);
      },
    ),
    GoRoute(
      path: '/logs',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LogsView(),
    ),
    GoRoute(
      path: '/websites',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WebsitesManagementView(),
    ),
    GoRoute(
      path: '/search-console',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SearchConsoleView(),
    ),
    GoRoute(
      path: '/bing-webmaster',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BingWebmasterView(),
    ),
    GoRoute(
      path: '/yandex-webmaster',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const YandexWebmasterView(),
    ),
    GoRoute(
      path: '/sync-history',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SyncHistoryView(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return NavigationShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Overview (Dashboard)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardView(),
            ),
          ],
        ),

        // Tab 1: Keywords Management
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/keywords',
              builder: (context, state) => const KeywordsListView(),
            ),
          ],
        ),

        // Tab 2: SEO Intelligence & Analysis
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analysis',
              builder: (context, state) => const AnalysisView(),
            ),
          ],
        ),

        // Tab 3: SERP Audit (Manual Tracking)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/manual-tracking',
              builder: (context, state) => const ManualTrackingView(),
            ),
          ],
        ),

        // Tab 4: Search Engines Hub
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search-engines',
              builder: (context, state) => const SearchEnginesView(),
            ),
          ],
        ),

        // Tab 5: Settings & Preferences
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsView(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Default static router instance for backward compatibility.
final GoRouter appRouter = createAppRouter();
