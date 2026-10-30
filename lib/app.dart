import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

/// Root application widget for RankScope.
class RankScopeApp extends StatelessWidget {
  const RankScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RankScope',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Strictly light mode only
      routerConfig: appRouter,
    );
  }
}
