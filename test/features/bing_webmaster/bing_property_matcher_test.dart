import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/bing_webmaster/domain/entities/bing_site_property.dart';
import 'package:rankscope/features/bing_webmaster/domain/utils/bing_property_matcher.dart';

void main() {
  group('BingPropertyMatcher Canonicalization Tests', () {
    test(
      'Canonicalizes raw domain strings removing protocols, www, and slashes',
      () {
        expect(
          BingPropertyMatcher.canonicalDomain('https://www.example.com/'),
          'example.com',
        );
        expect(
          BingPropertyMatcher.canonicalDomain('http://example.com'),
          'example.com',
        );
        expect(
          BingPropertyMatcher.canonicalDomain('EXAMPLE.COM/'),
          'example.com',
        );
        expect(
          BingPropertyMatcher.canonicalDomain('https://example.com:8080/path'),
          'example.com',
        );
        expect(
          BingPropertyMatcher.canonicalDomain('sub.domain.org'),
          'sub.domain.org',
        );
      },
    );
  });

  group('BingPropertyMatcher Matching Scenarios', () {
    final properties = [
      const BingSiteProperty(
        url: 'https://verified-site.com/',
        isVerified: true,
      ),
      const BingSiteProperty(
        url: 'http://unverified-site.com/',
        isVerified: false,
      ),
      const BingSiteProperty(
        url: 'https://multi-protocol.org/',
        isVerified: true,
      ),
      const BingSiteProperty(
        url: 'http://multi-protocol.org/',
        isVerified: false,
      ),
    ];

    test('Matches verified property and returns exact Bing URL', () {
      final result = BingPropertyMatcher.match(
        localDomain: 'verified-site.com',
        bingProperties: properties,
      );

      expect(result.status, BingVerificationStatus.verifiedAndMatched);
      expect(result.matchedBingUrl, 'https://verified-site.com/');
      expect(result.isSyncAllowed, isTrue);
    });

    test('Matches domain with www prefix against non-www Bing property', () {
      final result = BingPropertyMatcher.match(
        localDomain: 'www.verified-site.com',
        bingProperties: properties,
      );

      expect(result.status, BingVerificationStatus.verifiedAndMatched);
      expect(result.matchedBingUrl, 'https://verified-site.com/');
    });

    test('Matches unverified property and flags locallyAddedNotVerified', () {
      final result = BingPropertyMatcher.match(
        localDomain: 'unverified-site.com',
        bingProperties: properties,
      );

      expect(result.status, BingVerificationStatus.locallyAddedNotVerified);
      expect(result.matchedBingUrl, 'http://unverified-site.com/');
      expect(result.isSyncAllowed, isFalse);
    });

    test('Prioritizes HTTPS verified property when multiple exist', () {
      final result = BingPropertyMatcher.match(
        localDomain: 'multi-protocol.org',
        bingProperties: properties,
      );

      expect(result.status, BingVerificationStatus.verifiedAndMatched);
      expect(result.matchedBingUrl, 'https://multi-protocol.org/');
    });

    test('Returns propertyNotFound when domain is not in Bing account', () {
      final result = BingPropertyMatcher.match(
        localDomain: 'unknown-site.io',
        bingProperties: properties,
      );

      expect(result.status, BingVerificationStatus.propertyNotFound);
      expect(result.matchedBingUrl, isNull);
      expect(result.isSyncAllowed, isFalse);
      expect(result.availableProperties.length, 4);
    });

    test('Returns propertyNotFound on empty domain string', () {
      final result = BingPropertyMatcher.match(
        localDomain: '',
        bingProperties: properties,
      );

      expect(result.status, BingVerificationStatus.propertyNotFound);
      expect(result.matchedBingUrl, isNull);
    });
  });
}
