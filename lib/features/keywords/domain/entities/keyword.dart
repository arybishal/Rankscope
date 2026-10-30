/// Pure Domain Entity representing a tracked keyword for a specific website.
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
  final int positionDelta; // previousPosition - latestPosition (positive = gain)
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
}
