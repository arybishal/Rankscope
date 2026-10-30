/// Unified Domain Model representing a tracked keyword for a specific website.
class Keyword {
  final int? id;
  final int websiteId;
  final String keywordText;
  final String? targetUrl;
  final String targetCountry; // ISO 3166-1 alpha-2 or 'GLOBAL'
  final String? targetCity;
  final String searchEngine; // 'Google', 'Bing'
  final String language; // e.g. 'en', 'es'
  final String device; // 'Desktop', 'Mobile'
  final List<String> tags;
  final bool isActive;
  final String? rankingUrl; // Currently observed ranking page URL

  // Search Console & Search Performance Specific (Statistical Averages)
  final double? googleAveragePosition;
  final String? googleRankingUrl;
  final int googleImpressions;
  final int googleClicks;
  final double googleCtr;
  final DateTime? googleSyncedAt;

  final double? bingAveragePosition;
  final String? bingRankingUrl;
  final int bingImpressions;
  final int bingClicks;
  final double bingCtr;
  final DateTime? bingSyncedAt;

  final String urlMatchStatus; // 'matches_target', 'different_page', 'no_target_set', 'no_ranking_url', 'unknown'

  // Search Engine Specific Positions (SERP audit / integer observations)
  final int? googlePosition;
  final int? bingPosition;
  final int? googlePreviousPosition;
  final int? bingPreviousPosition;
  final int googleDelta;
  final int bingDelta;

  // Global / Legacy Position properties for compatibility
  final int? latestPosition;
  final int? previousPosition;
  final int positionDelta;

  // Intelligence & Alerts
  final String cannibalizationStatus; // 'none', 'potential', 'multiple_urls', 'url_switching', 'resolved'
  final String statusEvent; // 'normal', 'new', 'lost', 'recovered'
  final DateTime? firstRankedAt;
  final DateTime? lostAt;
  final DateTime? lastCheckedAt;
  final DateTime createdAt;

  const Keyword({
    this.id,
    required this.websiteId,
    required this.keywordText,
    this.targetUrl,
    this.targetCountry = 'GLOBAL',
    this.targetCity,
    this.searchEngine = 'Google',
    this.language = 'en',
    this.device = 'Desktop',
    this.tags = const [],
    this.isActive = true,
    this.rankingUrl,
    this.googleAveragePosition,
    this.googleRankingUrl,
    this.googleImpressions = 0,
    this.googleClicks = 0,
    this.googleCtr = 0.0,
    this.googleSyncedAt,
    this.bingAveragePosition,
    this.bingRankingUrl,
    this.bingImpressions = 0,
    this.bingClicks = 0,
    this.bingCtr = 0.0,
    this.bingSyncedAt,
    this.urlMatchStatus = 'unknown',
    this.googlePosition,
    this.bingPosition,
    this.googlePreviousPosition,
    this.bingPreviousPosition,
    this.googleDelta = 0,
    this.bingDelta = 0,
    this.latestPosition,
    this.previousPosition,
    this.positionDelta = 0,
    this.cannibalizationStatus = 'none',
    this.statusEvent = 'normal',
    this.firstRankedAt,
    this.lostAt,
    this.lastCheckedAt,
    required this.createdAt,
  });

  /// Helper to get position for a specific engine ('Google' or 'Bing').
  /// Defaults to latestPosition if engine-specific position is null.
  int? positionFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingPosition;
    }
    return googlePosition ?? latestPosition;
  }

  /// Helper to get delta for a specific engine ('Google' or 'Bing').
  int deltaFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingDelta;
    }
    return googleDelta != 0 ? googleDelta : positionDelta;
  }

  /// Helper to get search console / webmaster average position for an engine.
  double? averagePositionFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingAveragePosition;
    }
    if (engine.toLowerCase() == 'google') {
      return googleAveragePosition;
    }
    return googleAveragePosition ?? bingAveragePosition;
  }

  /// Helper to get impressions for a given engine.
  int impressionsFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingImpressions;
    }
    if (engine.toLowerCase() == 'google') {
      return googleImpressions;
    }
    return googleImpressions + bingImpressions;
  }

  /// Helper to get clicks for a given engine.
  int clicksFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingClicks;
    }
    if (engine.toLowerCase() == 'google') {
      return googleClicks;
    }
    return googleClicks + bingClicks;
  }

  /// Helper to get ranking URL for a given engine.
  String? performanceRankingUrlFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingRankingUrl ?? rankingUrl;
    }
    if (engine.toLowerCase() == 'google') {
      return googleRankingUrl ?? rankingUrl;
    }
    return googleRankingUrl ?? bingRankingUrl ?? rankingUrl;
  }

  /// Helper to get latest sync timestamp for a given engine.
  DateTime? syncedAtFor(String engine) {
    if (engine.toLowerCase() == 'bing') {
      return bingSyncedAt;
    }
    if (engine.toLowerCase() == 'google') {
      return googleSyncedAt;
    }
    if (googleSyncedAt == null) return bingSyncedAt;
    if (bingSyncedAt == null) return googleSyncedAt;
    return googleSyncedAt!.isAfter(bingSyncedAt!)
        ? googleSyncedAt
        : bingSyncedAt;
  }

  /// True if keyword is actively ranking (position >= 1).
  bool isRankingIn(String? engine) {
    final pos = engine != null
        ? positionFor(engine)
        : (googlePosition ?? bingPosition ?? latestPosition);
    return pos != null && pos > 0;
  }

  /// True if keyword is confirmed not ranking (position == 0).
  bool isNotRankingIn(String? engine) {
    final pos = engine != null
        ? positionFor(engine)
        : (googlePosition ?? bingPosition ?? latestPosition);
    return pos == 0;
  }

  bool get isNew => statusEvent == 'new';
  bool get isLost => statusEvent == 'lost';
  bool get isRecovered => statusEvent == 'recovered';
  bool get hasCannibalization =>
      cannibalizationStatus != 'none' && cannibalizationStatus != 'resolved';

  bool get hasGoogleData =>
      googleAveragePosition != null || googleImpressions > 0;
  bool get hasBingData => bingAveragePosition != null || bingImpressions > 0;
  bool get hasPerformanceData => hasGoogleData || hasBingData;

  factory Keyword.fromMap(Map<String, dynamic> map) {
    final tagsRaw = map['tags'] as String?;
    final List<String> parsedTags =
        (tagsRaw != null && tagsRaw.trim().isNotEmpty)
        ? tagsRaw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList()
        : [];

    final rawLatest = map['latest_position'] as int?;
    final rawGooglePos = map['google_position'] as int? ?? rawLatest;

    return Keyword(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      keywordText: map['keyword_text'] as String,
      targetUrl: map['target_url'] as String?,
      targetCountry: map['target_country'] as String? ?? 'GLOBAL',
      targetCity: map['target_city'] as String?,
      searchEngine: map['search_engine'] as String? ?? 'Google',
      language: map['language'] as String? ?? 'en',
      device: map['device'] as String? ?? 'Desktop',
      tags: parsedTags,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      rankingUrl: map['ranking_url'] as String?,
      googleAveragePosition: (map['google_average_position'] as num?)
          ?.toDouble(),
      googleRankingUrl: map['google_ranking_url'] as String?,
      googleImpressions: map['google_impressions'] as int? ?? 0,
      googleClicks: map['google_clicks'] as int? ?? 0,
      googleCtr: (map['google_ctr'] as num?)?.toDouble() ?? 0.0,
      googleSyncedAt: map['google_synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['google_synced_at'] as int)
          : null,
      bingAveragePosition: (map['bing_average_position'] as num?)?.toDouble(),
      bingRankingUrl: map['bing_ranking_url'] as String?,
      bingImpressions: map['bing_impressions'] as int? ?? 0,
      bingClicks: map['bing_clicks'] as int? ?? 0,
      bingCtr: (map['bing_ctr'] as num?)?.toDouble() ?? 0.0,
      bingSyncedAt: map['bing_synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['bing_synced_at'] as int)
          : null,
      urlMatchStatus: map['url_match_status'] as String? ?? 'unknown',
      googlePosition: rawGooglePos,
      bingPosition: map['bing_position'] as int?,
      googlePreviousPosition:
          map['google_previous_position'] as int? ??
          map['previous_position'] as int?,
      bingPreviousPosition: map['bing_previous_position'] as int?,
      googleDelta:
          map['google_delta'] as int? ?? map['position_delta'] as int? ?? 0,
      bingDelta: map['bing_delta'] as int? ?? 0,
      latestPosition: rawLatest,
      previousPosition: map['previous_position'] as int?,
      positionDelta: map['position_delta'] as int? ?? 0,
      cannibalizationStatus: map['cannibalization_status'] as String? ?? 'none',
      statusEvent: map['status_event'] as String? ?? 'normal',
      firstRankedAt: map['first_ranked_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['first_ranked_at'] as int)
          : null,
      lostAt: map['lost_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lost_at'] as int)
          : null,
      lastCheckedAt: map['last_checked_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_checked_at'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  factory Keyword.fromEntity(Keyword entity) => entity;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'website_id': websiteId,
      'keyword_text': keywordText,
      'target_url': targetUrl,
      'target_country': targetCountry,
      'target_city': targetCity,
      'search_engine': searchEngine,
      'language': language,
      'device': device,
      'tags': tags.isEmpty ? null : tags.join(','),
      'is_active': isActive ? 1 : 0,
      'ranking_url': rankingUrl,
      'google_average_position': googleAveragePosition,
      'google_ranking_url': googleRankingUrl,
      'google_impressions': googleImpressions,
      'google_clicks': googleClicks,
      'google_ctr': googleCtr,
      'google_synced_at': googleSyncedAt?.millisecondsSinceEpoch,
      'bing_average_position': bingAveragePosition,
      'bing_ranking_url': bingRankingUrl,
      'bing_impressions': bingImpressions,
      'bing_clicks': bingClicks,
      'bing_ctr': bingCtr,
      'bing_synced_at': bingSyncedAt?.millisecondsSinceEpoch,
      'url_match_status': urlMatchStatus,
      'google_position': googlePosition,
      'bing_position': bingPosition,
      'google_previous_position': googlePreviousPosition,
      'bing_previous_position': bingPreviousPosition,
      'google_delta': googleDelta,
      'bing_delta': bingDelta,
      'latest_position': latestPosition,
      'previous_position': previousPosition,
      'position_delta': positionDelta,
      'cannibalization_status': cannibalizationStatus,
      'status_event': statusEvent,
      'first_ranked_at': firstRankedAt?.millisecondsSinceEpoch,
      'lost_at': lostAt?.millisecondsSinceEpoch,
      'last_checked_at': lastCheckedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Keyword copyWith({
    int? id,
    int? websiteId,
    String? keywordText,
    String? targetUrl,
    String? targetCountry,
    String? targetCity,
    String? searchEngine,
    String? language,
    String? device,
    List<String>? tags,
    bool? isActive,
    String? rankingUrl,
    double? googleAveragePosition,
    String? googleRankingUrl,
    int? googleImpressions,
    int? googleClicks,
    double? googleCtr,
    DateTime? googleSyncedAt,
    double? bingAveragePosition,
    String? bingRankingUrl,
    int? bingImpressions,
    int? bingClicks,
    double? bingCtr,
    DateTime? bingSyncedAt,
    String? urlMatchStatus,
    int? googlePosition,
    int? bingPosition,
    int? googlePreviousPosition,
    int? bingPreviousPosition,
    int? googleDelta,
    int? bingDelta,
    int? latestPosition,
    int? previousPosition,
    int? positionDelta,
    String? cannibalizationStatus,
    String? statusEvent,
    DateTime? firstRankedAt,
    DateTime? lostAt,
    DateTime? lastCheckedAt,
    DateTime? createdAt,
  }) {
    return Keyword(
      id: id ?? this.id,
      websiteId: websiteId ?? this.websiteId,
      keywordText: keywordText ?? this.keywordText,
      targetUrl: targetUrl ?? this.targetUrl,
      targetCountry: targetCountry ?? this.targetCountry,
      targetCity: targetCity ?? this.targetCity,
      searchEngine: searchEngine ?? this.searchEngine,
      language: language ?? this.language,
      device: device ?? this.device,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      rankingUrl: rankingUrl ?? this.rankingUrl,
      googleAveragePosition:
          googleAveragePosition ?? this.googleAveragePosition,
      googleRankingUrl: googleRankingUrl ?? this.googleRankingUrl,
      googleImpressions: googleImpressions ?? this.googleImpressions,
      googleClicks: googleClicks ?? this.googleClicks,
      googleCtr: googleCtr ?? this.googleCtr,
      googleSyncedAt: googleSyncedAt ?? this.googleSyncedAt,
      bingAveragePosition: bingAveragePosition ?? this.bingAveragePosition,
      bingRankingUrl: bingRankingUrl ?? this.bingRankingUrl,
      bingImpressions: bingImpressions ?? this.bingImpressions,
      bingClicks: bingClicks ?? this.bingClicks,
      bingCtr: bingCtr ?? this.bingCtr,
      bingSyncedAt: bingSyncedAt ?? this.bingSyncedAt,
      urlMatchStatus: urlMatchStatus ?? this.urlMatchStatus,
      googlePosition: googlePosition ?? this.googlePosition,
      bingPosition: bingPosition ?? this.bingPosition,
      googlePreviousPosition:
          googlePreviousPosition ?? this.googlePreviousPosition,
      bingPreviousPosition: bingPreviousPosition ?? this.bingPreviousPosition,
      googleDelta: googleDelta ?? this.googleDelta,
      bingDelta: bingDelta ?? this.bingDelta,
      latestPosition: latestPosition ?? this.latestPosition,
      previousPosition: previousPosition ?? this.previousPosition,
      positionDelta: positionDelta ?? this.positionDelta,
      cannibalizationStatus:
          cannibalizationStatus ?? this.cannibalizationStatus,
      statusEvent: statusEvent ?? this.statusEvent,
      firstRankedAt: firstRankedAt ?? this.firstRankedAt,
      lostAt: lostAt ?? this.lostAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Keyword &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          websiteId == other.websiteId &&
          keywordText == other.keywordText &&
          searchEngine == other.searchEngine &&
          targetCountry == other.targetCountry &&
          device == other.device;

  @override
  int get hashCode =>
      id.hashCode ^
      websiteId.hashCode ^
      keywordText.hashCode ^
      searchEngine.hashCode ^
      targetCountry.hashCode ^
      device.hashCode;
}
