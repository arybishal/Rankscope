import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/logging/app_logger.dart';
import 'core/security/secure_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Framework error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.instance.error(
      'FlutterFramework',
      'flutter_error',
      details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };

  // Platform and background task errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.critical(
      'PlatformDispatcher',
      'unhandled_exception',
      error.toString(),
      stackTrace: stack,
    );
    return true;
  };

  // Eagerly initialize SQLite database and apply any pending schema migrations
  await AppDatabase.instance.database;
  await AppLogger.instance.info(
    'App',
    'app_started',
    'RankScope engine initialized',
  );

  // Check first-time install onboarding completion
  String initialRoute = '/dashboard';
  try {
    final storage = SecureStorageService();
    final hasCompleted = await storage.hasCompletedOnboarding();
    if (!hasCompleted) {
      initialRoute = '/onboarding';
    }
  } catch (e, stack) {
    await AppLogger.instance.error(
      'App',
      'onboarding_check_failed',
      'Could not verify onboarding state: $e',
      stackTrace: stack,
    );
  }

  runApp(ProviderScope(child: RankScopeApp(initialLocation: initialRoute)));
}
