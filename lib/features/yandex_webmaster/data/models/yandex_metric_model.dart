import '../../domain/entities/yandex_metric.dart';

/// Model representing a Yandex search query metric item parsed from official Yandex API.
class YandexMetricModel extends YandexMetric {
  const YandexMetricModel({
    super.id,
    required super.websiteId,
    required super.query,
    super.pageUrl,
    super.deviceType,
    required super.metricDate,
    required super.clicks,
    required super.impressions,
    required super.ctr,
    required super.averagePosition,
    super.averageClickPosition,
    required super.syncedAt,
  });

  /// Parses from a single item in Yandex Webmaster popular search queries API:
  /// `GET /v4/user/{user_id}/hosts/{host_id}/search-queries/popular`
  factory YandexMetricModel.fromYandexJson({
    required Map<String, dynamic> json,
    required int websiteId,
    required String metricDate,
    required DateTime syncedAt,
    String? deviceType,
  }) {
    final queryText = json['query_text'] as String? ?? '';
    final indicators = json['indicators'] as Map<String, dynamic>? ?? {};

    final shows = (indicators['TOTAL_SHOWS'] as num?)?.toInt() ?? 0;
    final clicks = (indicators['TOTAL_CLICKS'] as num?)?.toInt() ?? 0;
    final avgShowPos =
        (indicators['AVG_SHOW_POSITION'] as num?)?.toDouble() ?? 0.0;
    final avgClickPos =
        (indicators['AVG_CLICK_POSITION'] as num?)?.toDouble();

    final ctr = shows > 0 ? (clicks / shows) : 0.0;

    return YandexMetricModel(
      websiteId: websiteId,
      query: queryText,
      deviceType: deviceType ?? 'ALL',
      metricDate: metricDate,
      clicks: clicks,
      impressions: shows,
      ctr: ctr,
      averagePosition: avgShowPos,
      averageClickPosition: avgClickPos,
      syncedAt: syncedAt,
    );
  }

  factory YandexMetricModel.fromMap(Map<String, dynamic> map) {
    return YandexMetricModel(
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
}
