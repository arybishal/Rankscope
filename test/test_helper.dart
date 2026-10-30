import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
export 'package:sqflite_common_ffi/sqflite_ffi.dart' show inMemoryDatabasePath;

/// Initializes SQLite FFI factory for local desktop and headless CI tests.
void setupSqfliteFfi() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Mocks FlutterSecureStorage platform channel for desktop and unit tests.
void setupMockSecureStorage([Map<String, String>? initialValues]) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final values = initialValues ?? <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      final args = call.arguments as Map?;
      if (call.method == 'read') {
        return values[args?['key']];
      } else if (call.method == 'write') {
        if (args != null && args['key'] != null) {
          values[args['key'] as String] = args['value'] as String;
        }
        return null;
      } else if (call.method == 'delete') {
        if (args != null) values.remove(args['key']);
        return null;
      } else if (call.method == 'deleteAll') {
        values.clear();
        return null;
      }
      return null;
    },
  );
}
