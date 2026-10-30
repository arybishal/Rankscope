/// Domain Entity representing a discrete point-in-time SERP audit observation.
class ManualRankRecord {
  final int? id;
  final int keywordId;
  final int websiteId;
  final int position; // 1 to 100
  final String? rankingUrl;
  final String searchEngine; // Google, Bing, Yahoo, DuckDuckGo, Other
  final String locationCountry;
  final String? locationCity;
  final int serpFeaturesMask;
  final String? notes;
  final DateTime recordedAt;

  const ManualRankRecord({
    this.id,
    required this.keywordId,
    required this.websiteId,
    required this.position,
    this.rankingUrl,
    this.searchEngine = 'Google',
    this.locationCountry = 'GLOBAL',
    this.locationCity,
    this.serpFeaturesMask = 0,
    this.notes,
    required this.recordedAt,
  });

  // Bitmask helpers
  bool get hasFeaturedSnippet => (serpFeaturesMask & 1) != 0;
  bool get hasLocalPack => (serpFeaturesMask & 2) != 0;
  bool get hasPeopleAlsoAsk => (serpFeaturesMask & 4) != 0;
  bool get hasVideoCarousel => (serpFeaturesMask & 8) != 0;
  bool get hasImagePack => (serpFeaturesMask & 16) != 0;
  bool get hasSitelinks => (serpFeaturesMask & 32) != 0;
  bool get hasKnowledgePanel => (serpFeaturesMask & 64) != 0;

  static int buildBitmask({
    bool featuredSnippet = false,
    bool localPack = false,
    bool peopleAlsoAsk = false,
    bool videoCarousel = false,
    bool imagePack = false,
    bool sitelinks = false,
    bool knowledgePanel = false,
  }) {
    int mask = 0;
    if (featuredSnippet) mask |= 1;
    if (localPack) mask |= 2;
    if (peopleAlsoAsk) mask |= 4;
    if (videoCarousel) mask |= 8;
    if (imagePack) mask |= 16;
    if (sitelinks) mask |= 32;
    if (knowledgePanel) mask |= 64;
    return mask;
  }
}
