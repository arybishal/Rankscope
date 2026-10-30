import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

/// Root application widget for RankScope.
class RankScopeApp extends StatefulWidget {
  final String initialLocation;
  final RouterConfig<Object>? routerConfig;

  const RankScopeApp({
    super.key,
    this.initialLocation = '/dashboard',
    this.routerConfig,
  });

  @override
  State<RankScopeApp> createState() => _RankScopeAppState();
}

class _RankScopeAppState extends State<RankScopeApp> {
  late final RouterConfig<Object> _router;

  @override
  void initState() {
    super.initState();
    _router =
        widget.routerConfig ??
        (widget.initialLocation == '/dashboard'
            ? appRouter
            : createAppRouter(initialLocation: widget.initialLocation));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RankScope',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Strictly light mode only
      routerConfig: _router,
    );
  }
}
