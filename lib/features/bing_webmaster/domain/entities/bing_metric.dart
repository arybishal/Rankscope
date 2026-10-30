/// Domain Entity representing Bing Webmaster Tools query metrics.
class BingMetric {
  final int? id;
  final int websiteId;
  final String query;
  final String? pageUrl;
  final String metricDate;
  final int clicks;
  final int impressions;
  final double ctr;
  final double averagePosition;
  final DateTime syncedAt;

  const BingMetric({
    this.id,
    required this.websiteId,
    required this.query,
    this.pageUrl,
    required this.metricDate,
    required this.clicks,
    required this.impressions,
    required this.ctr,
    required this.averagePosition,
    required this.syncedAt,
  });
}
