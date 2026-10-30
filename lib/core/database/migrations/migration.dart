import 'package:sqflite/sqflite.dart';

/// Base contract for atomic database schema migrations.
abstract class Migration {
  int get version;
  String get name;
  Future<void> execute(DatabaseExecutor db);
}
