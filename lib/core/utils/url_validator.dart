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

  /// Normalizes a full URL for canonical SEO page comparison.
  ///
  /// Strips protocol (http/https), www prefix, default ports, trailing slashes,
  /// and hash fragments, while lowercasing the domain and preserving path structure.
  static String normalizeUrl(String rawUrl) {
    if (rawUrl.trim().isEmpty) return '';
    String cleaned = rawUrl.trim();

    // Strip hash fragment
    final hashIndex = cleaned.indexOf('#');
    if (hashIndex != -1) {
      cleaned = cleaned.substring(0, hashIndex);
    }

    // Strip protocol
    if (cleaned.toLowerCase().startsWith('https://')) {
      cleaned = cleaned.substring(8);
    } else if (cleaned.toLowerCase().startsWith('http://')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('//')) {
      cleaned = cleaned.substring(2);
    }

    // Strip www prefix
    if (cleaned.toLowerCase().startsWith('www.')) {
      cleaned = cleaned.substring(4);
    }

    // Separate host and path
    final slashIndex = cleaned.indexOf('/');
    String host;
    String path = '';
    if (slashIndex != -1) {
      host = cleaned.substring(0, slashIndex).toLowerCase();
      path = cleaned.substring(slashIndex);
    } else {
      host = cleaned.toLowerCase();
    }

    // Remove default port from host
    final colonIndex = host.indexOf(':');
    if (colonIndex != -1) {
      final port = host.substring(colonIndex + 1);
      if (port == '80' || port == '443') {
        host = host.substring(0, colonIndex);
      }
    }

    // Normalize path: strip trailing slash unless path is just empty or '/'
    while (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    if (path == '/') {
      path = '';
    }

    return '$host$path'.toLowerCase();
  }

  /// Determines whether an actual ranking URL matches an expected target URL.
  static bool urlsMatch(String? expectedTargetUrl, String? actualRankingUrl) {
    if (expectedTargetUrl == null || actualRankingUrl == null) return false;
    final normTarget = normalizeUrl(expectedTargetUrl);
    final normRanking = normalizeUrl(actualRankingUrl);
    if (normTarget.isEmpty || normRanking.isEmpty) return false;
    return normTarget == normRanking;
  }

  /// Computes the URL match status for a keyword.
  ///
  /// Possible statuses:
  /// - 'matches_target': ranking URL matches target URL
  /// - 'different_page': page ranking is different from expected target URL
  /// - 'no_target_set': target URL was not provided for this keyword
  /// - 'no_ranking_url': search performance data did not provide a landing page URL
  static String computeUrlMatchStatus(
    String? expectedTargetUrl,
    String? actualRankingUrl,
  ) {
    if (expectedTargetUrl == null || expectedTargetUrl.trim().isEmpty) {
      return 'no_target_set';
    }
    if (actualRankingUrl == null || actualRankingUrl.trim().isEmpty) {
      return 'no_ranking_url';
    }
    return urlsMatch(expectedTargetUrl, actualRankingUrl)
        ? 'matches_target'
        : 'different_page';
  }
}
