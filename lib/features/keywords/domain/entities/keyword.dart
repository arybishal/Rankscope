/// Unified Domain Model representing a tracked keyword for a specific website.
class Keyword {
  final int? id;
  final int websiteId;
  final String keywordText;
  final String? targetUrl;
  final String targetCountry; // ISO 3166-1 alpha-2 or 'GLOBAL'
  final String? targetCity;
  final List<String> tags;
  final bool isActive;
  final int? latestPosition;
  final int? previousPosition;
  final int
  positionDelta; // previousPosition - latestPosition (positive = gain)
  final DateTime? lastCheckedAt;
  final DateTime createdAt;

  const Keyword({
    this.id,
    required this.websiteId,
    required this.keywordText,
    this.targetUrl,
    this.targetCountry = 'GLOBAL',
    this.targetCity,
    this.tags = const [],
    this.isActive = true,
    this.latestPosition,
    this.previousPosition,
    this.positionDelta = 0,
    this.lastCheckedAt,
    required this.createdAt,
  });

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

    return Keyword(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      keywordText: map['keyword_text'] as String,
      targetUrl: map['target_url'] as String?,
      targetCountry: map['target_country'] as String? ?? 'GLOBAL',
      targetCity: map['target_city'] as String?,
      tags: parsedTags,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      latestPosition: map['latest_position'] as int?,
      previousPosition: map['previous_position'] as int?,
      positionDelta: map['position_delta'] as int? ?? 0,
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
      'tags': tags.isEmpty ? null : tags.join(','),
      'is_active': isActive ? 1 : 0,
      'latest_position': latestPosition,
      'previous_position': previousPosition,
      'position_delta': positionDelta,
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
    List<String>? tags,
    bool? isActive,
    int? latestPosition,
    int? previousPosition,
    int? positionDelta,
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
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      latestPosition: latestPosition ?? this.latestPosition,
      previousPosition: previousPosition ?? this.previousPosition,
      positionDelta: positionDelta ?? this.positionDelta,
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
          targetCountry == other.targetCountry &&
          targetCity == other.targetCity;

  @override
  int get hashCode =>
      id.hashCode ^
      websiteId.hashCode ^
      keywordText.hashCode ^
      targetCountry.hashCode ^
      targetCity.hashCode;
}
