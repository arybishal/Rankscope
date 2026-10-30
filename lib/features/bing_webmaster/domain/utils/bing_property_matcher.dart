import '../entities/bing_site_property.dart';

/// Utility to perform canonical domain and URL matching between local websites
/// and properties registered in Bing Webmaster Tools.
class BingPropertyMatcher {
  BingPropertyMatcher._();

  /// Canonicalizes a domain or URL for matching purposes by:
  /// 1. Trimming and converting to lowercase.
  /// 2. Removing 'http://' or 'https://' protocols.
  /// 3. Removing path, query strings, and trailing slashes.
  /// 4. Removing port numbers.
  /// 5. Stripping the 'www.' prefix.
  static String canonicalDomain(String raw) {
    String cleaned = raw.trim().toLowerCase();

    // Remove protocol
    if (cleaned.startsWith('https://')) {
      cleaned = cleaned.substring(8);
    } else if (cleaned.startsWith('http://')) {
      cleaned = cleaned.substring(7);
    }

    // Remove path or query parameters
    final slashIndex = cleaned.indexOf('/');
    if (slashIndex != -1) {
      cleaned = cleaned.substring(0, slashIndex);
    }

    // Remove port if present
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex != -1) {
      cleaned = cleaned.substring(0, colonIndex);
    }

    // Strip leading 'www.'
    if (cleaned.startsWith('www.')) {
      cleaned = cleaned.substring(4);
    }

    return cleaned.trim();
  }

  /// Matches a local domain string against the list of properties returned by Bing.
  ///
  /// Matching algorithm:
  /// 1. Normalizes local domain and all Bing property URLs to canonical domains.
  /// 2. Finds all Bing properties that match the canonical domain.
  /// 3. If none match -> returns [BingVerificationStatus.propertyNotFound].
  /// 4. If matching properties exist, checks for verified ones (`isVerified == true`).
  ///    - If verified exists: prioritizes HTTPS over HTTP, then returns
  ///      [BingVerificationStatus.verifiedAndMatched] with the exact compatible URL.
  ///    - If only unverified exist: returns [BingVerificationStatus.locallyAddedNotVerified].
  static BingPropertyMatchResult match({
    required String localDomain,
    required List<BingSiteProperty> bingProperties,
  }) {
    final targetCanonical = canonicalDomain(localDomain);

    if (targetCanonical.isEmpty) {
      return BingPropertyMatchResult(
        status: BingVerificationStatus.propertyNotFound,
        availableProperties: bingProperties,
        errorMessage: 'Local domain is empty or invalid.',
      );
    }

    final matchingProperties = bingProperties.where((prop) {
      final propCanonical = canonicalDomain(prop.url);
      return propCanonical == targetCanonical;
    }).toList();

    if (matchingProperties.isEmpty) {
      return BingPropertyMatchResult(
        status: BingVerificationStatus.propertyNotFound,
        availableProperties: bingProperties,
        errorMessage:
            'Domain "$targetCanonical" was not found in your Bing Webmaster account.',
      );
    }

    // Check for verified matches
    final verifiedMatches = matchingProperties
        .where((prop) => prop.isVerified)
        .toList();

    if (verifiedMatches.isNotEmpty) {
      // Prioritize HTTPS if available
      final preferred = verifiedMatches.firstWhere(
        (prop) => prop.url.toLowerCase().startsWith('https://'),
        orElse: () => verifiedMatches.first,
      );

      return BingPropertyMatchResult(
        status: BingVerificationStatus.verifiedAndMatched,
        matchedBingUrl: preferred.url,
        availableProperties: bingProperties,
      );
    }

    // Property exists in Bing account, but ownership verification is incomplete
    return BingPropertyMatchResult(
      status: BingVerificationStatus.locallyAddedNotVerified,
      matchedBingUrl: matchingProperties.first.url,
      availableProperties: bingProperties,
      errorMessage:
          'Property "${matchingProperties.first.url}" exists in Bing Webmaster, but ownership is not verified.',
    );
  }
}
