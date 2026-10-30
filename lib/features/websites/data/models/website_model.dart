import '../../domain/entities/website.dart';

/// Data transfer model for [Website] mapping to SQLite rows.
class WebsiteModel extends Website {
  const WebsiteModel({
    super.id,
    required super.domain,
    required super.label,
    super.isCompetitor,
    super.gscPropertyId,
    super.bingSiteUrl,
    super.faviconUrl,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory WebsiteModel.fromEntity(Website entity) {
    return WebsiteModel(
      id: entity.id,
      domain: entity.domain,
      label: entity.label,
      isCompetitor: entity.isCompetitor,
      gscPropertyId: entity.gscPropertyId,
      bingSiteUrl: entity.bingSiteUrl,
      faviconUrl: entity.faviconUrl,
      notes: entity.notes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory WebsiteModel.fromMap(Map<String, dynamic> map) {
    return WebsiteModel(
      id: map['id'] as int?,
      domain: map['domain'] as String,
      label: map['label'] as String,
      isCompetitor: (map['is_competitor'] as int? ?? 0) == 1,
      gscPropertyId: map['gsc_property_id'] as String?,
      bingSiteUrl: map['bing_site_url'] as String?,
      faviconUrl: map['favicon_url'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'domain': domain,
      'label': label,
      'is_competitor': isCompetitor ? 1 : 0,
      'gsc_property_id': gscPropertyId,
      'bing_site_url': bingSiteUrl,
      'favicon_url': faviconUrl,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}
