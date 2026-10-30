/// Pure Domain Entity representing a tracked website (own domain or competitor).
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
}
