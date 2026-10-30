import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly initialize SQLite database and apply any pending schema migrations
  await AppDatabase.instance.database;

  runApp(
    const ProviderScope(
      child: RankScopeApp(),
    ),
  );
}
