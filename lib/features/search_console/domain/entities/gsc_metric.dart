/// Domain Entity representing Google Search Console aggregated performance data.
class GscMetric {
  final int? id;
  final int websiteId;
  final String query;
  final String pageUrl;
  final String countryCode;
  final String deviceType; // all, DESKTOP, MOBILE, TABLET
  final String metricDate; // YYYY-MM-DD
  final int clicks;
  final int impressions;
  final double ctr;
  final double averagePosition; // Statistical aggregate from GSC
  final DateTime syncedAt;

  const GscMetric({
    this.id,
    required this.websiteId,
    required this.query,
    required this.pageUrl,
    this.countryCode = 'all',
    this.deviceType = 'all',
    required this.metricDate,
    required this.clicks,
    required this.impressions,
    required this.ctr,
    required this.averagePosition,
    required this.syncedAt,
  });
}
