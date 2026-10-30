/// Redaction and data sanitization utility to ensure sensitive credentials,
/// OAuth tokens, passwords, and private API keys are NEVER logged or exported in plain text.
class LogSanitizer {
  LogSanitizer._();

  static final List<RegExp> _sensitivePatterns = [
    // Bearer tokens & Authorization headers
    RegExp(r'(Authorization:\s*Bearer\s+)[^\s\r\n]+', caseSensitive: false),
    RegExp(r'(Bearer\s+)[a-zA-Z0-9_\-\.]{15,}', caseSensitive: false),
    
    // Google OAuth access & refresh tokens
    RegExp(r'ya29\.[a-zA-Z0-9_\-\.]+'),
    RegExp(r'1\/\/[a-zA-Z0-9_\-]{20,}'),

    // Passwords & Secrets in key-value pairs or JSON (handles quoted and unquoted values)
    RegExp(r'''(password\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''', caseSensitive: false),
    RegExp(r'''(client_secret\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''', caseSensitive: false),
    RegExp(r'''(api_?key\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''', caseSensitive: false),
    RegExp(r'''(refresh_token\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''', caseSensitive: false),
    RegExp(r'''(access_token\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''', caseSensitive: false),
    
    // Bing 32-char hex API key pattern
    RegExp(r'\b[0-9a-fA-F]{32}\b'),
  ];

  /// Scrubs and masks sensitive information from log messages and stack traces.
  static String sanitize(String? raw) {
    if (raw == null || raw.isEmpty) return '';

    String cleaned = raw;
    for (final pattern in _sensitivePatterns) {
      cleaned = cleaned.replaceAllMapped(pattern, (match) {
        if (match.groupCount >= 1 && match.group(1) != null) {
          return '${match.group(1)}"[REDACTED]"';
        }
        return '[REDACTED]';
      });
    }

    return cleaned;
  }
}
