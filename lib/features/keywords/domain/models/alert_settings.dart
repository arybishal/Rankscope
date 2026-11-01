/// User configurable settings and thresholds for SEO ranking alerts.
class AlertSettings {
  final int rankGainThreshold; // Default: 3 positions improved
  final int rankDropThreshold; // Default: 3 positions dropped
  final bool rankGainEnabled;
  final bool rankDropEnabled;
  final bool newQueryEnabled;
  final bool lostQueryEnabled;
  final bool urlChangeEnabled;
  final bool cannibalizationEnabled;
  final bool localNotificationsEnabled;

  const AlertSettings({
    this.rankGainThreshold = 3,
    this.rankDropThreshold = 3,
    this.rankGainEnabled = true,
    this.rankDropEnabled = true,
    this.newQueryEnabled = true,
    this.lostQueryEnabled = true,
    this.urlChangeEnabled = true,
    this.cannibalizationEnabled = true,
    this.localNotificationsEnabled = true,
  });

  AlertSettings copyWith({
    int? rankGainThreshold,
    int? rankDropThreshold,
    bool? rankGainEnabled,
    bool? rankDropEnabled,
    bool? newQueryEnabled,
    bool? lostQueryEnabled,
    bool? urlChangeEnabled,
    bool? cannibalizationEnabled,
    bool? localNotificationsEnabled,
  }) {
    return AlertSettings(
      rankGainThreshold: rankGainThreshold ?? this.rankGainThreshold,
      rankDropThreshold: rankDropThreshold ?? this.rankDropThreshold,
      rankGainEnabled: rankGainEnabled ?? this.rankGainEnabled,
      rankDropEnabled: rankDropEnabled ?? this.rankDropEnabled,
      newQueryEnabled: newQueryEnabled ?? this.newQueryEnabled,
      lostQueryEnabled: lostQueryEnabled ?? this.lostQueryEnabled,
      urlChangeEnabled: urlChangeEnabled ?? this.urlChangeEnabled,
      cannibalizationEnabled:
          cannibalizationEnabled ?? this.cannibalizationEnabled,
      localNotificationsEnabled:
          localNotificationsEnabled ?? this.localNotificationsEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rank_gain_threshold': rankGainThreshold,
      'rank_drop_threshold': rankDropThreshold,
      'rank_gain_enabled': rankGainEnabled,
      'rank_drop_enabled': rankDropEnabled,
      'new_query_enabled': newQueryEnabled,
      'lost_query_enabled': lostQueryEnabled,
      'url_change_enabled': urlChangeEnabled,
      'cannibalization_enabled': cannibalizationEnabled,
      'local_notifications_enabled': localNotificationsEnabled,
    };
  }

  factory AlertSettings.fromMap(Map<String, dynamic> map) {
    return AlertSettings(
      rankGainThreshold: (map['rank_gain_threshold'] as num?)?.toInt() ?? 3,
      rankDropThreshold: (map['rank_drop_threshold'] as num?)?.toInt() ?? 3,
      rankGainEnabled: map['rank_gain_enabled'] as bool? ?? true,
      rankDropEnabled: map['rank_drop_enabled'] as bool? ?? true,
      newQueryEnabled: map['new_query_enabled'] as bool? ?? true,
      lostQueryEnabled: map['lost_query_enabled'] as bool? ?? true,
      urlChangeEnabled: map['url_change_enabled'] as bool? ?? true,
      cannibalizationEnabled: map['cannibalization_enabled'] as bool? ?? true,
      localNotificationsEnabled:
          map['local_notifications_enabled'] as bool? ?? true,
    );
  }
}
