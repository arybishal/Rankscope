/// Confidence rating for keyword cannibalization diagnosis.
enum CannibalizationConfidence {
  high,
  medium,
  low,
}

/// URL metrics associated with a competing page under a single keyword query.
class CannibalizationUrlMetric {
  final String url;
  final int impressions;
  final int clicks;
  final double? averagePosition;
  final DateTime? latestSeen;

  const CannibalizationUrlMetric({
    required this.url,
    this.impressions = 0,
    this.clicks = 0,
    this.averagePosition,
    this.latestSeen,
  });
}

/// Diagnostic entity describing detected cannibalization competition across multiple landing pages.
class CannibalizationFinding {
  final int keywordId;
  final int websiteId;
  final String keywordText;
  final String searchEngine;
  final List<CannibalizationUrlMetric> affectedUrls;
  final CannibalizationConfidence confidence;
  final String dateRange;
  final String evidence;
  final String recommendation;

  const CannibalizationFinding({
    required this.keywordId,
    required this.websiteId,
    required this.keywordText,
    required this.searchEngine,
    required this.affectedUrls,
    required this.confidence,
    required this.dateRange,
    required this.evidence,
    required this.recommendation,
  });

  String get confidenceLabel {
    switch (confidence) {
      case CannibalizationConfidence.high:
        return 'High Confidence';
      case CannibalizationConfidence.medium:
        return 'Medium Confidence';
      case CannibalizationConfidence.low:
        return 'Low Confidence (Sporadic)';
    }
  }
}
