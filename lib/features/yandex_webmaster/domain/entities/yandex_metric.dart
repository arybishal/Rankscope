/// Domain entity representing a search query metric observation from Yandex Webmaster.
class YandexMetric {
  final int? id;
  final int websiteId;
  final String query;
  final String? pageUrl;
  final String? deviceType;
  final String metricDate;
  final int clicks;
  final int impressions;
  final double ctr;
  final double averagePosition;
  final double? averageClickPosition;
  final DateTime syncedAt;

  const YandexMetric({
    this.id,
    required this.websiteId,
    required this.query,
    this.pageUrl,
    this.deviceType = 'ALL',
    required this.metricDate,
    required this.clicks,
    required this.impressions,
    required this.ctr,
    required this.averagePosition,
    this.averageClickPosition,
    required this.syncedAt,
  });

  factory YandexMetric.fromMap(Map<String, dynamic> map) {
    return YandexMetric(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      query: map['query'] as String,
      pageUrl: map['page_url'] as String?,
      deviceType: map['device_type'] as String? ?? 'ALL',
      metricDate: map['metric_date'] as String,
      clicks: map['clicks'] as int? ?? 0,
      impressions: map['impressions'] as int? ?? 0,
      ctr: (map['ctr'] as num?)?.toDouble() ?? 0.0,
      averagePosition: (map['average_position'] as num?)?.toDouble() ?? 0.0,
      averageClickPosition: (map['average_click_position'] as num?)?.toDouble(),
      syncedAt: DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'website_id': websiteId,
      'query': query,
      'page_url': pageUrl,
      'device_type': deviceType,
      'metric_date': metricDate,
      'clicks': clicks,
      'impressions': impressions,
      'ctr': ctr,
      'average_position': averagePosition,
      'average_click_position': averageClickPosition,
      'synced_at': syncedAt.millisecondsSinceEpoch,
    };
  }
}
