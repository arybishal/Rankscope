import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/core/utils/url_validator.dart';

void main() {
  group('UrlValidator', () {
    test('normalizes domains by removing protocols and trailing slashes', () {
      expect(UrlValidator.normalizeDomain('https://example.com/'), 'example.com');
      expect(UrlValidator.normalizeDomain('http://www.sub.domain.co.uk/path?q=1'), 'sub.domain.co.uk');
      expect(UrlValidator.normalizeDomain('EXAMPLE.COM'), 'example.com');
      expect(UrlValidator.normalizeDomain('mybrand.org:8080'), 'mybrand.org');
    });

    test('validates valid domain names', () {
      expect(UrlValidator.isValidDomain('example.com'), isTrue);
      expect(UrlValidator.isValidDomain('https://flutter.dev'), isTrue);
      expect(UrlValidator.isValidDomain('sub-domain.brand.io'), isTrue);
    });

    test('rejects invalid domain names', () {
      expect(UrlValidator.isValidDomain(''), isFalse);
      expect(UrlValidator.isValidDomain('not a domain'), isFalse);
      expect(UrlValidator.isValidDomain('http://'), isFalse);
    });
  });
}
