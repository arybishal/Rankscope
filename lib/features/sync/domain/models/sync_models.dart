import 'dart:convert';

/// Status of individual search engine sync for a website.
class EngineSyncDetail {
  final String engine; // 'Google', 'Bing', 'Yandex'
  final bool isConnected;
  final bool isSuccess;
  final int queriesCount;
  final String? message;
  final String? error;

  const EngineSyncDetail({
    required this.engine,
    required this.isConnected,
    required this.isSuccess,
    this.queriesCount = 0,
    this.message,
    this.error,
  });

  Map<String, dynamic> toMap() => {
    'engine': engine,
    'isConnected': isConnected,
    'isSuccess': isSuccess,
    'queriesCount': queriesCount,
    'message': message,
    'error': error,
  };

  factory EngineSyncDetail.fromMap(Map<String, dynamic> map) =>
      EngineSyncDetail(
        engine: map['engine'] as String? ?? '',
        isConnected: map['isConnected'] as bool? ?? false,
        isSuccess: map['isSuccess'] as bool? ?? false,
        queriesCount: map['queriesCount'] as int? ?? 0,
        message: map['message'] as String?,
        error: map['error'] as String?,
      );
}

/// Status and metrics of an individual website synchronization run.
class WebsiteSyncDetail {
  final int websiteId;
  final String domain;
  final String label;
  final bool isSuccess;
  final int totalKeywords;
  final int matchedKeywords;
  final List<EngineSyncDetail> engineDetails;
  final String? errorMessage;

  const WebsiteSyncDetail({
    required this.websiteId,
    required this.domain,
    required this.label,
    required this.isSuccess,
    this.totalKeywords = 0,
    this.matchedKeywords = 0,
    this.engineDetails = const [],
    this.errorMessage,
  });

  EngineSyncDetail? getEngine(String name) {
    try {
      return engineDetails.firstWhere(
        (e) => e.engine.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
    'websiteId': websiteId,
    'domain': domain,
    'label': label,
    'isSuccess': isSuccess,
    'totalKeywords': totalKeywords,
    'matchedKeywords': matchedKeywords,
    'engineDetails': engineDetails.map((e) => e.toMap()).toList(),
    'errorMessage': errorMessage,
  };

  factory WebsiteSyncDetail.fromMap(Map<String, dynamic> map) =>
      WebsiteSyncDetail(
        websiteId: map['websiteId'] as int? ?? 0,
        domain: map['domain'] as String? ?? '',
        label: map['label'] as String? ?? '',
        isSuccess: map['isSuccess'] as bool? ?? false,
        totalKeywords: map['totalKeywords'] as int? ?? 0,
        matchedKeywords: map['matchedKeywords'] as int? ?? 0,
        engineDetails: (map['engineDetails'] as List<dynamic>? ?? [])
            .map((e) => EngineSyncDetail.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        errorMessage: map['errorMessage'] as String?,
      );
}

/// Overall summary of a multi-website sync execution (auto or manual).
class SyncSummary {
  final DateTime startedAt;
  final DateTime completedAt;
  final String status; // 'success', 'partial_success', 'failed'
  final int totalWebsites;
  final int successfulWebsites;
  final int failedWebsites;
  final int totalQueriesSynced;
  final bool isBackground;
  final List<WebsiteSyncDetail> websiteDetails;
  final String overallMessage;

  const SyncSummary({
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.totalWebsites,
    required this.successfulWebsites,
    required this.failedWebsites,
    required this.totalQueriesSynced,
    this.isBackground = false,
    this.websiteDetails = const [],
    required this.overallMessage,
  });

  bool get isSuccess => status == 'success';
  bool get hasFailures => failedWebsites > 0;

  int get googleQueries => websiteDetails.fold<int>(0, (sum, site) {
        final g = site.getEngine('Google');
        return sum + (g?.queriesCount ?? 0);
      });

  int get bingQueries => websiteDetails.fold<int>(0, (sum, site) {
        final b = site.getEngine('Bing');
        return sum + (b?.queriesCount ?? 0);
      });

  int get yandexQueries => websiteDetails.fold<int>(0, (sum, site) {
        final y = site.getEngine('Yandex');
        return sum + (y?.queriesCount ?? 0);
      });

  int get totalMatchedKeywords => websiteDetails.fold<int>(
        0,
        (sum, site) => sum + site.matchedKeywords,
      );

  Map<String, dynamic> toMap() => {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'completedAt': completedAt.millisecondsSinceEpoch,
    'status': status,
    'totalWebsites': totalWebsites,
    'successfulWebsites': successfulWebsites,
    'failedWebsites': failedWebsites,
    'totalQueriesSynced': totalQueriesSynced,
    'isBackground': isBackground,
    'websiteDetails': websiteDetails.map((w) => w.toMap()).toList(),
    'overallMessage': overallMessage,
  };

  String toJson() => jsonEncode(toMap());

  factory SyncSummary.fromMap(Map<String, dynamic> map) => SyncSummary(
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      map['startedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    ),
    completedAt: DateTime.fromMillisecondsSinceEpoch(
      map['completedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    ),
    status: map['status'] as String? ?? 'success',
    totalWebsites: map['totalWebsites'] as int? ?? 0,
    successfulWebsites: map['successfulWebsites'] as int? ?? 0,
    failedWebsites: map['failedWebsites'] as int? ?? 0,
    totalQueriesSynced: map['totalQueriesSynced'] as int? ?? 0,
    isBackground: map['isBackground'] as bool? ?? false,
    websiteDetails: (map['websiteDetails'] as List<dynamic>? ?? [])
        .map((w) => WebsiteSyncDetail.fromMap(Map<String, dynamic>.from(w as Map)))
        .toList(),
    overallMessage: map['overallMessage'] as String? ?? '',
  );

  factory SyncSummary.fromJson(String jsonStr) =>
      SyncSummary.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}

/// Progress state emitted during execution of Sync All.
class SyncProgress {
  final int currentStep;
  final int totalSteps;
  final String currentWebsiteDomain;
  final String currentOperation;
  final bool isCompleted;
  final SyncSummary? summary;

  const SyncProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.currentWebsiteDomain,
    required this.currentOperation,
    this.isCompleted = false,
    this.summary,
  });

  double get percent =>
      totalSteps > 0 ? (currentStep / totalSteps).clamp(0.0, 1.0) : 0.0;
}
