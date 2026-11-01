/// Domain Entity representing a ranking change alert, search visibility anomaly, or cannibalization alert.
class RankingAlert {
  final int? id;
  final int websiteId;
  final int? keywordId;
  final String alertType; // 'rank_gain', 'rank_drop', 'new_query', 'lost_query', 'url_change', 'cannibalization'
  final String severity; // 'info', 'warning', 'critical'
  final String title;
  final String message;
  final String searchEngine; // 'Google', 'Bing', 'Yandex'
  final String? detailsJson;
  final bool isRead;
  final DateTime createdAt;

  const RankingAlert({
    this.id,
    required this.websiteId,
    this.keywordId,
    required this.alertType,
    this.severity = 'info',
    required this.title,
    required this.message,
    this.searchEngine = 'Google',
    this.detailsJson,
    this.isRead = false,
    required this.createdAt,
  });

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
  bool get isInfo => severity == 'info';

  factory RankingAlert.fromMap(Map<String, dynamic> map) {
    return RankingAlert(
      id: map['id'] as int?,
      websiteId: map['website_id'] as int,
      keywordId: map['keyword_id'] as int?,
      alertType: map['alert_type'] as String,
      severity: map['severity'] as String? ?? 'info',
      title: map['title'] as String,
      message: map['message'] as String,
      searchEngine: map['search_engine'] as String? ?? 'Google',
      detailsJson: map['details_json'] as String?,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'website_id': websiteId,
      'keyword_id': keywordId,
      'alert_type': alertType,
      'severity': severity,
      'title': title,
      'message': message,
      'search_engine': searchEngine,
      'details_json': detailsJson,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  RankingAlert copyWith({
    int? id,
    int? websiteId,
    int? keywordId,
    String? alertType,
    String? severity,
    String? title,
    String? message,
    String? searchEngine,
    String? detailsJson,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return RankingAlert(
      id: id ?? this.id,
      websiteId: websiteId ?? this.websiteId,
      keywordId: keywordId ?? this.keywordId,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      searchEngine: searchEngine ?? this.searchEngine,
      detailsJson: detailsJson ?? this.detailsJson,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RankingAlert &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          websiteId == other.websiteId &&
          keywordId == other.keywordId &&
          alertType == other.alertType &&
          title == other.title;

  @override
  int get hashCode =>
      id.hashCode ^
      websiteId.hashCode ^
      (keywordId?.hashCode ?? 0) ^
      alertType.hashCode ^
      title.hashCode;
}
