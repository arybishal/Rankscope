import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'routing/app_router.dart';

/// Root application widget for RankScope.
class RankScopeApp extends ConsumerStatefulWidget {
  final String initialLocation;
  final RouterConfig<Object>? routerConfig;

  const RankScopeApp({
    super.key,
    this.initialLocation = '/dashboard',
    this.routerConfig,
  });

  @override
  ConsumerState<RankScopeApp> createState() => _RankScopeAppState();
}

class _RankScopeAppState extends ConsumerState<RankScopeApp> {
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
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'RankScope',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
