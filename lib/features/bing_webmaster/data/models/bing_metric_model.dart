import '../../domain/entities/bing_metric.dart';

/// Data transfer model for [BingMetric].
class BingMetricModel extends BingMetric {
  const BingMetricModel({
    super.id,
    required super.websiteId,
    required super.query,
    super.pageUrl,
    required super.metricDate,
    required super.clicks,
    required super.impressions,
    required super.ctr,
    required super.averagePosition,
    required super.syncedAt,
  });

  factory BingMetricModel.fromMap(Map<String, dynamic> map) {
    return BingMetricModel(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      query: map['query'] as String,
      pageUrl: map['page_url'] as String?,
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
      'metric_date': metricDate,
      'clicks': clicks,
      'impressions': impressions,
      'ctr': ctr,
      'average_position': averagePosition,
      'synced_at': syncedAt.millisecondsSinceEpoch,
    };
  }

  /// Parses row from Bing GetQueryStats JSON:
  /// {"Query":"flutter seo","Clicks":12,"Impressions":240,"AvgClickPosition":4.2,"Date":"\/Date(1600000000000)\/"}
  factory BingMetricModel.fromBingJson(
    Map<String, dynamic> json,
    int websiteId,
    DateTime syncedAt,
  ) {
    final query = json['Query'] as String? ?? '';
    final clicks = json['Clicks'] as int? ?? 0;
    final impressions = json['Impressions'] as int? ?? 0;
    final avgPos = (json['AvgClickPosition'] as num?)?.toDouble() ?? 0.0;
    final ctr = impressions > 0 ? (clicks / impressions) : 0.0;

    String dateStr = '';
    final rawDate = json['Date'] as String?;
    if (rawDate != null) {
      final match = RegExp(r'\d+').firstMatch(rawDate);
      if (match != null) {
        final ms = int.tryParse(match.group(0)!) ?? 0;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        dateStr =
            "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
    }
    if (dateStr.isEmpty) {
      final now = DateTime.now();
      dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    }

    return BingMetricModel(
      websiteId: websiteId,
      query: query,
      metricDate: dateStr,
      clicks: clicks,
      impressions: impressions,
      ctr: ctr,
      averagePosition: avgPos,
      syncedAt: syncedAt,
    );
  }
}
