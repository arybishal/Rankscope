/// Severity levels for RankScope application diagnostic logging.
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical;

  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRITICAL';
    }
  }

  static LogLevel fromString(String val) {
    switch (val.toUpperCase()) {
      case 'DEBUG':
        return LogLevel.debug;
      case 'INFO':
        return LogLevel.info;
      case 'WARNING':
      case 'WARN':
        return LogLevel.warning;
      case 'ERROR':
        return LogLevel.error;
      case 'CRITICAL':
        return LogLevel.critical;
      default:
        return LogLevel.info;
    }
  }
}
