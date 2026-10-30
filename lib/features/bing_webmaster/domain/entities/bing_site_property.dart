/// Represents a website property registered in the user's Bing Webmaster account.
class BingSiteProperty {
  final String url;
  final bool isVerified;
  final String? authenticationCode;
  final int? failureCode;

  const BingSiteProperty({
    required this.url,
    required this.isVerified,
    this.authenticationCode,
    this.failureCode,
  });

  factory BingSiteProperty.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['Url'] ?? json['url'] ?? '').toString().trim();
    final rawVerified =
        json['IsVerified'] ??
        json['is_verified'] ??
        json['isVerified'] ??
        false;

    final isVerified =
        rawVerified == true ||
        rawVerified == 1 ||
        rawVerified.toString().toLowerCase() == 'true';

    final authCode =
        (json['AuthenticationCode'] ??
                json['authentication_code'] ??
                json['authenticationCode'])
            ?.toString();

    final failure = json['FailureCode'] is int
        ? json['FailureCode'] as int
        : int.tryParse(json['FailureCode']?.toString() ?? '');

    return BingSiteProperty(
      url: rawUrl,
      isVerified: isVerified,
      authenticationCode: authCode,
      failureCode: failure,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'isVerified': isVerified,
    'authenticationCode': authenticationCode,
    'failureCode': failureCode,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BingSiteProperty &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          isVerified == other.isVerified;

  @override
  int get hashCode => url.hashCode ^ isVerified.hashCode;
}

/// Status of local website match against Bing Webmaster account properties.
enum BingVerificationStatus {
  /// Property is registered and successfully verified in Bing Webmaster.
  verifiedAndMatched,

  /// Property is listed in user's Bing account, but ownership verification is incomplete in Bing.
  locallyAddedNotVerified,

  /// Local website domain does not exist in user's Bing Webmaster account.
  propertyNotFound,

  /// Bing API authentication failed (e.g. invalid or revoked API key).
  authFailed,

  /// Network error, timeout, or unreachable Bing Webmaster API.
  connectionUnavailable,

  /// Bing API key is not configured in settings.
  notConfigured,
}

/// The result of evaluating a local domain against Bing Webmaster account properties.
class BingPropertyMatchResult {
  final BingVerificationStatus status;
  final String? matchedBingUrl;
  final List<BingSiteProperty> availableProperties;
  final String? errorMessage;

  const BingPropertyMatchResult({
    required this.status,
    this.matchedBingUrl,
    this.availableProperties = const [],
    this.errorMessage,
  });

  /// True only when property is confirmed verified in Bing and safe to sync.
  bool get isSyncAllowed => status == BingVerificationStatus.verifiedAndMatched;

  /// Human-friendly display label for the status.
  String get displayTitle {
    switch (status) {
      case BingVerificationStatus.verifiedAndMatched:
        return 'Verified and Matched';
      case BingVerificationStatus.locallyAddedNotVerified:
        return 'Added Locally, Not Verified in Bing';
      case BingVerificationStatus.propertyNotFound:
        return 'Bing Property Not Found';
      case BingVerificationStatus.authFailed:
        return 'Authentication Failed';
      case BingVerificationStatus.connectionUnavailable:
        return 'Connection Unavailable';
      case BingVerificationStatus.notConfigured:
        return 'Bing API Key Not Configured';
    }
  }
}
