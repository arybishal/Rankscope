/// Unified Domain Model representing a tracked website (own domain or competitor).
class Website {
  final int? id;
  final String domain;
  final String label;
  final bool isCompetitor;
  final String? gscPropertyId;
  final String? bingSiteUrl;
  final String? faviconUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Website({
    this.id,
    required this.domain,
    required this.label,
    this.isCompetitor = false,
    this.gscPropertyId,
    this.bingSiteUrl,
    this.faviconUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Website.fromMap(Map<String, dynamic> map) {
    return Website(
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

  factory Website.fromEntity(Website entity) => entity;

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

  Website copyWith({
    int? id,
    String? domain,
    String? label,
    bool? isCompetitor,
    String? gscPropertyId,
    String? bingSiteUrl,
    String? faviconUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Website(
      id: id ?? this.id,
      domain: domain ?? this.domain,
      label: label ?? this.label,
      isCompetitor: isCompetitor ?? this.isCompetitor,
      gscPropertyId: gscPropertyId ?? this.gscPropertyId,
      bingSiteUrl: bingSiteUrl ?? this.bingSiteUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Website &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          domain == other.domain &&
          label == other.label &&
          isCompetitor == other.isCompetitor;

  @override
  int get hashCode =>
      id.hashCode ^ domain.hashCode ^ label.hashCode ^ isCompetitor.hashCode;
}

/// Extension on [Iterable<Website>] providing safe null-safe lookups without throwing StateErrors or type cast errors.
extension WebsiteListExtension on Iterable<Website> {
  /// Finds a website by ID or returns `null` if not found.
  Website? findById(int? id) {
    if (id == null) return null;
    for (final website in this) {
      if (website.id == id) return website;
    }
    return null;
  }

  /// Safely resolves the active website matching [selectedId], or falls back to the first available website.
  /// Returns `null` if the list is empty.
  Website? findActive(int? selectedId) {
    if (isEmpty) return null;
    return findById(selectedId) ?? firstOrNull;
  }
}
