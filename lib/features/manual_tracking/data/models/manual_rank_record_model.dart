import '../../domain/entities/manual_rank_record.dart';

/// Data transfer model for [ManualRankRecord] mapping to SQLite.
class ManualRankRecordModel extends ManualRankRecord {
  const ManualRankRecordModel({
    super.id,
    required super.keywordId,
    required super.websiteId,
    required super.position,
    super.rankingUrl,
    super.searchEngine,
    super.locationCountry,
    super.locationCity,
    super.serpFeaturesMask,
    super.notes,
    required super.recordedAt,
  });

  factory ManualRankRecordModel.fromEntity(ManualRankRecord entity) {
    return ManualRankRecordModel(
      id: entity.id,
      keywordId: entity.keywordId,
      websiteId: entity.websiteId,
      position: entity.position,
      rankingUrl: entity.rankingUrl,
      searchEngine: entity.searchEngine,
      locationCountry: entity.locationCountry,
      locationCity: entity.locationCity,
      serpFeaturesMask: entity.serpFeaturesMask,
      notes: entity.notes,
      recordedAt: entity.recordedAt,
    );
  }

  factory ManualRankRecordModel.fromMap(Map<String, dynamic> map) {
    return ManualRankRecordModel(
      id: map['id'] as int?,
      keywordId: map['keyword_id'] as int,
      websiteId: map['website_id'] as int,
      position: map['position'] as int,
      rankingUrl: map['ranking_url'] as String?,
      searchEngine: map['search_engine'] as String? ?? 'Google',
      locationCountry: map['location_country'] as String? ?? 'GLOBAL',
      locationCity: map['location_city'] as String?,
      serpFeaturesMask: map['serp_features_mask'] as int? ?? 0,
      notes: map['notes'] as String?,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map['recorded_at'] as int,
      ),
    );
  }

  ManualRankRecordModel copyWith({
    int? id,
    int? keywordId,
    int? websiteId,
    int? position,
    String? rankingUrl,
    String? searchEngine,
    String? locationCountry,
    String? locationCity,
    int? serpFeaturesMask,
    String? notes,
    DateTime? recordedAt,
  }) {
    return ManualRankRecordModel(
      id: id ?? this.id,
      keywordId: keywordId ?? this.keywordId,
      websiteId: websiteId ?? this.websiteId,
      position: position ?? this.position,
      rankingUrl: rankingUrl ?? this.rankingUrl,
      searchEngine: searchEngine ?? this.searchEngine,
      locationCountry: locationCountry ?? this.locationCountry,
      locationCity: locationCity ?? this.locationCity,
      serpFeaturesMask: serpFeaturesMask ?? this.serpFeaturesMask,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'keyword_id': keywordId,
      'website_id': websiteId,
      'position': position,
      'ranking_url': rankingUrl,
      'search_engine': searchEngine,
      'location_country': locationCountry,
      'location_city': locationCity,
      'serp_features_mask': serpFeaturesMask,
      'notes': notes,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
    };
  }
}
