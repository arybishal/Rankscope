import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/logging/app_logger.dart';

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
  await AppLogger.instance.info('App', 'app_started', 'RankScope engine initialized');

  runApp(
    const ProviderScope(
      child: RankScopeApp(),
    ),
  );
}
