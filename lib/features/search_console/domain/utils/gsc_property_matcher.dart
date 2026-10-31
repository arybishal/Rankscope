/// Utility for resolving and matching local website domains to Google Search Console
/// verified site properties (supporting both domain properties like 'sc-domain:example.com'
/// and URL-prefix properties like 'https://example.com/').
class GscPropertyMatcher {
  const GscPropertyMatcher._();

  /// Normalizes a domain or URL to its bare hostname without protocol, www, or trailing slash.
  static String normalizeToBareDomain(String input) {
    String cleaned = input.trim().toLowerCase();

    // Strip sc-domain: prefix
    if (cleaned.startsWith('sc-domain:')) {
      cleaned = cleaned.substring('sc-domain:'.length);
    }

    // Strip protocol
    if (cleaned.startsWith('https://')) {
      cleaned = cleaned.substring('https://'.length);
    } else if (cleaned.startsWith('http://')) {
      cleaned = cleaned.substring('http://'.length);
    }

    // Strip path and query parameters
    final slashIndex = cleaned.indexOf('/');
    if (slashIndex != -1) {
      cleaned = cleaned.substring(0, slashIndex);
    }

    // Strip www. prefix
    if (cleaned.startsWith('www.')) {
      cleaned = cleaned.substring(4);
    }

    return cleaned.trim();
  }

  /// Finds the best matching verified property URL from GSC for a given local domain.
  ///
  /// Returns the exact property string as registered in GSC, or null if no match found.
  static String? findMatchingProperty(
    String localDomain,
    List<String> verifiedProperties,
  ) {
    if (verifiedProperties.isEmpty) return null;

    final targetBare = normalizeToBareDomain(localDomain);
    if (targetBare.isEmpty) return null;

    // 1. Check for exact sc-domain match: sc-domain:example.com
    for (final prop in verifiedProperties) {
      if (prop.toLowerCase() == 'sc-domain:$targetBare') {
        return prop;
      }
    }

    // 2. Check for URL-prefix matching https://example.com/ or https://www.example.com/
    for (final prop in verifiedProperties) {
      final propBare = normalizeToBareDomain(prop);
      if (propBare == targetBare) {
        return prop;
      }
    }

    // 3. Partial / subdomain match if local domain contains or is contained in property
    for (final prop in verifiedProperties) {
      final propBare = normalizeToBareDomain(prop);
      if (propBare.endsWith('.$targetBare') || targetBare.endsWith('.$propBare')) {
        return prop;
      }
    }

    return null;
  }

  /// Builds a default fallback site URL if not verified or discoverable.
  static String defaultSiteUrl(String domain) {
    final trimmed = domain.trim();
    if (trimmed.startsWith('sc-domain:') || trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.endsWith('/') || trimmed.startsWith('sc-domain:')
          ? trimmed
          : '$trimmed/';
    }
    return 'https://$trimmed/';
  }
}
