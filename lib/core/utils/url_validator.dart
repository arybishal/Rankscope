/// Utilities for validating and normalizing domain names and URLs.
class UrlValidator {
  UrlValidator._();

  static final RegExp _domainRegex = RegExp(
    r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$',
  );

  /// Strips protocol, port, path, query parameters, and www prefix.
  static String normalizeDomain(String rawInput) {
    String cleaned = rawInput.trim().toLowerCase();

    // Remove protocol
    if (cleaned.startsWith('https://')) {
      cleaned = cleaned.substring(8);
    } else if (cleaned.startsWith('http://')) {
      cleaned = cleaned.substring(7);
    }

    // Remove path or query
    final slashIndex = cleaned.indexOf('/');
    if (slashIndex != -1) {
      cleaned = cleaned.substring(0, slashIndex);
    }

    // Remove port if present
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex != -1) {
      cleaned = cleaned.substring(0, colonIndex);
    }

    // Optional: strip www prefix
    if (cleaned.startsWith('www.')) {
      cleaned = cleaned.substring(4);
    }

    return cleaned.trim();
  }

  /// Validates whether a normalized domain conforms to standard FQDN rules.
  static bool isValidDomain(String domain) {
    final normalized = normalizeDomain(domain);
    return _domainRegex.hasMatch(normalized);
  }
}
