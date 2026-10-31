/// Entity representing a verified or registered host/site in Yandex Webmaster.
class YandexHost {
  final String hostId; // e.g. 'https:example.com:443'
  final String asciiHostUrl; // e.g. 'https://example.com/'
  final String unicodeHostUrl;
  final bool verified;
  final String? mainMirrorHostId;

  const YandexHost({
    required this.hostId,
    required this.asciiHostUrl,
    required this.unicodeHostUrl,
    required this.verified,
    this.mainMirrorHostId,
  });

  factory YandexHost.fromJson(Map<String, dynamic> json) {
    return YandexHost(
      hostId: json['host_id'] as String? ?? '',
      asciiHostUrl: json['ascii_host_url'] as String? ?? '',
      unicodeHostUrl: json['unicode_host_url'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      mainMirrorHostId: json['main_mirror'] != null
          ? (json['main_mirror']['host_id'] as String?)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host_id': hostId,
      'ascii_host_url': asciiHostUrl,
      'unicode_host_url': unicodeHostUrl,
      'verified': verified,
      if (mainMirrorHostId != null) 'main_mirror': {'host_id': mainMirrorHostId},
    };
  }

  /// Clean displayable URL/domain for UI selection.
  String get displayName {
    if (unicodeHostUrl.isNotEmpty) return unicodeHostUrl;
    if (asciiHostUrl.isNotEmpty) return asciiHostUrl;
    return hostId.replaceAll(':443', '').replaceAll(':80', '');
  }
}
