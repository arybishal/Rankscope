import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/bing_webmaster/presentation/views/bing_webmaster_view.dart';
import '../features/dashboard/presentation/views/dashboard_view.dart';
import '../features/manual_tracking/presentation/views/manual_tracking_view.dart';
import '../features/search_console/presentation/views/search_console_view.dart';
import '../features/settings/presentation/views/logs_view.dart';
import '../features/settings/presentation/views/settings_view.dart';
import 'navigation_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Declarative GoRouter routing tree for RankScope.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/logs',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LogsView(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return NavigationShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardView(),
            ),
          ],
        ),

        // Tab 1: Manual SERP Audit
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/manual-tracking',
              builder: (context, state) => const ManualTrackingView(),
            ),
          ],
        ),

        // Tab 2: Google Search Console
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search-console',
              builder: (context, state) => const SearchConsoleView(),
            ),
          ],
        ),

        // Tab 3: Bing Webmaster
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bing-webmaster',
              builder: (context, state) => const BingWebmasterView(),
            ),
          ],
        ),

        // Tab 4: Settings & Privacy
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
