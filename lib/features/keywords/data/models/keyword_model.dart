import '../../domain/entities/keyword.dart';

/// Data transfer model for [Keyword] mapping to SQLite.
class KeywordModel extends Keyword {
  const KeywordModel({
    super.id,
    required super.websiteId,
    required super.keywordText,
    super.targetUrl,
    super.targetCountry,
    super.targetCity,
    super.tags,
    super.isActive,
    super.latestPosition,
    super.previousPosition,
    super.positionDelta,
    super.lastCheckedAt,
    required super.createdAt,
  });

  factory KeywordModel.fromEntity(Keyword entity) {
    return KeywordModel(
      id: entity.id,
      websiteId: entity.websiteId,
      keywordText: entity.keywordText,
      targetUrl: entity.targetUrl,
      targetCountry: entity.targetCountry,
      targetCity: entity.targetCity,
      tags: entity.tags,
      isActive: entity.isActive,
      latestPosition: entity.latestPosition,
      previousPosition: entity.previousPosition,
      positionDelta: entity.positionDelta,
      lastCheckedAt: entity.lastCheckedAt,
      createdAt: entity.createdAt,
    );
  }

  factory KeywordModel.fromMap(Map<String, dynamic> map) {
    final tagsRaw = map['tags'] as String?;
    final List<String> parsedTags = (tagsRaw != null && tagsRaw.trim().isNotEmpty)
        ? tagsRaw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : [];

    return KeywordModel(
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

  @override
  KeywordModel copyWith({
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
    return KeywordModel(
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
}
