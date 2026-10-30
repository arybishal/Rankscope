/// Represents an individual historical rank observation recorded for a keyword.
class RankObservation {
  final int? id;
  final int keywordId;
  final int websiteId;
  final String searchEngine; // 'Google' or 'Bing'
  final int position; // 1-100, or 0 if confirmed not found in checked range
  final double?
  averagePosition; // Statistical average from Search Console / Bing
  final int clicks;
  final int impressions;
  final double ctr;
  final String? metricDate; // YYYY-MM-DD
  final String? rankingUrl;
  final String? previousRankingUrl;
  final bool isUrlChange;
  final String country;
  final String language;
  final String device;
  final DateTime recordedAt;
  final String source; // 'manual', 'bing_api', 'gsc'
  final String
  observationStatus; // 'ranking', 'not_ranking', 'pending', 'error'
  final String? notes;

  const RankObservation({
    this.id,
    required this.keywordId,
    required this.websiteId,
    this.searchEngine = 'Google',
    required this.position,
    this.averagePosition,
    this.clicks = 0,
    this.impressions = 0,
    this.ctr = 0.0,
    this.metricDate,
    this.rankingUrl,
    this.previousRankingUrl,
    this.isUrlChange = false,
    this.country = 'GLOBAL',
    this.language = 'en',
    this.device = 'Desktop',
    required this.recordedAt,
    this.source = 'manual',
    this.observationStatus = 'ranking',
    this.notes,
  });

  bool get isRanking =>
      (position > 0 || (averagePosition != null && averagePosition! > 0)) &&
      observationStatus == 'ranking';
  bool get isNotRanking => position == 0 || observationStatus == 'not_ranking';

  factory RankObservation.fromMap(Map<String, dynamic> map) {
    return RankObservation(
      id: map['id'] as int?,
      keywordId: map['keyword_id'] as int,
      websiteId: map['website_id'] as int,
      searchEngine: map['search_engine'] as String? ?? 'Google',
      position: map['position'] as int? ?? 0,
      averagePosition: (map['average_position'] as num?)?.toDouble(),
      clicks: map['clicks'] as int? ?? 0,
      impressions: map['impressions'] as int? ?? 0,
      ctr: (map['ctr'] as num?)?.toDouble() ?? 0.0,
      metricDate: map['metric_date'] as String?,
      rankingUrl: map['ranking_url'] as String?,
      previousRankingUrl: map['previous_ranking_url'] as String?,
      isUrlChange: (map['is_url_change'] as int? ?? 0) == 1,
      country: map['country'] as String? ?? 'GLOBAL',
      language: map['language'] as String? ?? 'en',
      device: map['device'] as String? ?? 'Desktop',
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map['recorded_at'] as int,
      ),
      source: map['source'] as String? ?? 'manual',
      observationStatus: map['observation_status'] as String? ?? 'ranking',
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'keyword_id': keywordId,
      'website_id': websiteId,
      'search_engine': searchEngine,
      'position': position,
      'average_position': averagePosition,
      'clicks': clicks,
      'impressions': impressions,
      'ctr': ctr,
      'metric_date': metricDate,
      'ranking_url': rankingUrl,
      'previous_ranking_url': previousRankingUrl,
      'is_url_change': isUrlChange ? 1 : 0,
      'country': country,
      'language': language,
      'device': device,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'source': source,
      'observation_status': observationStatus,
      'notes': notes,
    };
  }

  RankObservation copyWith({
    int? id,
    int? keywordId,
    int? websiteId,
    String? searchEngine,
    int? position,
    double? averagePosition,
    int? clicks,
    int? impressions,
    double? ctr,
    String? metricDate,
    String? rankingUrl,
    String? previousRankingUrl,
    bool? isUrlChange,
    String? country,
    String? language,
    String? device,
    DateTime? recordedAt,
    String? source,
    String? observationStatus,
    String? notes,
  }) {
    return RankObservation(
      id: id ?? this.id,
      keywordId: keywordId ?? this.keywordId,
      websiteId: websiteId ?? this.websiteId,
      searchEngine: searchEngine ?? this.searchEngine,
      position: position ?? this.position,
      averagePosition: averagePosition ?? this.averagePosition,
      clicks: clicks ?? this.clicks,
      impressions: impressions ?? this.impressions,
      ctr: ctr ?? this.ctr,
      metricDate: metricDate ?? this.metricDate,
      rankingUrl: rankingUrl ?? this.rankingUrl,
      previousRankingUrl: previousRankingUrl ?? this.previousRankingUrl,
      isUrlChange: isUrlChange ?? this.isUrlChange,
      country: country ?? this.country,
      language: language ?? this.language,
      device: device ?? this.device,
      recordedAt: recordedAt ?? this.recordedAt,
      source: source ?? this.source,
      observationStatus: observationStatus ?? this.observationStatus,
      notes: notes ?? this.notes,
    );
  }
}
