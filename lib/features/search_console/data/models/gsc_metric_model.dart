import '../../domain/entities/gsc_metric.dart';

/// Data transfer model for [GscMetric].
class GscMetricModel extends GscMetric {
  const GscMetricModel({
    super.id,
    required super.websiteId,
    required super.query,
    required super.pageUrl,
    super.countryCode,
    super.deviceType,
    required super.metricDate,
    required super.clicks,
    required super.impressions,
    required super.ctr,
    required super.averagePosition,
    required super.syncedAt,
  });

  factory GscMetricModel.fromMap(Map<String, dynamic> map) {
    return GscMetricModel(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      query: map['query'] as String,
      pageUrl: map['page_url'] as String,
      countryCode: map['country_code'] as String? ?? 'all',
      deviceType: map['device_type'] as String? ?? 'all',
      metricDate: map['metric_date'] as String,
      clicks: map['clicks'] as int? ?? 0,
      impressions: map['impressions'] as int? ?? 0,
      ctr: (map['ctr'] as num?)?.toDouble() ?? 0.0,
      averagePosition: (map['average_position'] as num?)?.toDouble() ?? 0.0,
      syncedAt: DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'website_id': websiteId,
      'query': query,
      'page_url': pageUrl,
      'country_code': countryCode,
      'device_type': deviceType,
      'metric_date': metricDate,
      'clicks': clicks,
      'impressions': impressions,
      'ctr': ctr,
      'average_position': averagePosition,
      'synced_at': syncedAt.millisecondsSinceEpoch,
    };
  }

  /// Parses row from GSC API SearchAnalyticsQueryResponse
  /// keys: [date, query, page, country, device]
  factory GscMetricModel.fromGscRow({
    required int websiteId,
    required List<dynamic> keys,
    required int clicks,
    required int impressions,
    required double ctr,
    required double position,
    required DateTime syncedAt,
  }) {
    final metricDate = keys.isNotEmpty ? keys[0].toString() : '';
    final query = keys.length > 1 ? keys[1].toString() : '';
    final page = keys.length > 2 ? keys[2].toString() : '';
    final country = keys.length > 3 ? keys[3].toString() : 'all';
    final device = keys.length > 4 ? keys[4].toString() : 'all';

    return GscMetricModel(
      websiteId: websiteId,
      query: query,
      pageUrl: page,
      countryCode: country,
      deviceType: device,
      metricDate: metricDate,
      clicks: clicks,
      impressions: impressions,
      ctr: ctr,
      averagePosition: position,
      syncedAt: syncedAt,
    );
  }
}
