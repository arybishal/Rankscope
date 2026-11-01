/// Represents a custom organizational group for tracked keywords in a website.
class KeywordGroup {
  final int? id;
  final int websiteId;
  final String name;
  final String? colorHex;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed summary metrics (optional, populated in summaries)
  final int keywordCount;
  final double? averagePosition;
  final int totalImpressions;
  final int totalClicks;
  final double averageCtr;

  const KeywordGroup({
    this.id,
    required this.websiteId,
    required this.name,
    this.colorHex,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.keywordCount = 0,
    this.averagePosition,
    this.totalImpressions = 0,
    this.totalClicks = 0,
    this.averageCtr = 0.0,
  });

  factory KeywordGroup.fromMap(Map<String, dynamic> map) {
    return KeywordGroup(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String?,
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      keywordCount: map['keyword_count'] as int? ?? 0,
      averagePosition: (map['average_position'] as num?)?.toDouble(),
      totalImpressions: map['total_impressions'] as int? ?? 0,
      totalClicks: map['total_clicks'] as int? ?? 0,
      averageCtr: (map['average_ctr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'website_id': websiteId,
      'name': name,
      'color_hex': colorHex,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  KeywordGroup copyWith({
    int? id,
    int? websiteId,
    String? name,
    String? colorHex,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? keywordCount,
    double? averagePosition,
    int? totalImpressions,
    int? totalClicks,
    double? averageCtr,
  }) {
    return KeywordGroup(
      id: id ?? this.id,
      websiteId: websiteId ?? this.websiteId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      keywordCount: keywordCount ?? this.keywordCount,
      averagePosition: averagePosition ?? this.averagePosition,
      totalImpressions: totalImpressions ?? this.totalImpressions,
      totalClicks: totalClicks ?? this.totalClicks,
      averageCtr: averageCtr ?? this.averageCtr,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          websiteId == other.websiteId &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ websiteId.hashCode ^ name.hashCode;
}
