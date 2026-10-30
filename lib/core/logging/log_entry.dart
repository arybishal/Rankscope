import 'log_level.dart';

/// Single diagnostic log entry stored in local SQLite database.
class LogEntry {
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final String module;
  final String eventName;
  final String message;
  final String? details;

  const LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.module,
    required this.eventName,
    required this.message,
    this.details,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      level: LogLevel.fromString(map['level'] as String),
      module: map['module'] as String,
      eventName: map['event_name'] as String,
      message: map['message'] as String,
      details: map['details'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'level': level.label,
      'module': module,
      'event_name': eventName,
      'message': message,
      'details': details,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.label,
      'module': module,
      'event_name': eventName,
      'message': message,
      if (details != null) 'details': details,
    };
  }

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write(
      '[${timestamp.toIso8601String()}] [${level.label}] [$module] $eventName: $message',
    );
    if (details != null && details!.isNotEmpty) {
      buffer.write('\nDetails:\n$details');
    }
    return buffer.toString();
  }
}
