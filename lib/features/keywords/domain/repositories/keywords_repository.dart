import '../entities/keyword.dart';
import '../entities/rank_observation.dart';

export '../entities/keyword.dart';
export '../entities/rank_observation.dart';

/// Repository interface for Keyword and Rank Observation operations.
abstract class KeywordsRepository {
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? searchEngine,
    String? tag,
  });

  Future<Keyword?> getKeywordById(int id);

  Future<Keyword?> findDuplicateKeyword({
    required int websiteId,
    required String keywordText,
    required String searchEngine,
    required String targetCountry,
    String? targetCity,
    String language = 'en',
    String device = 'Desktop',
    int? excludeId,
  });

  Future<Keyword> addKeyword(Keyword keyword);

  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords);

  Future<void> updateKeyword(Keyword keyword);

  Future<void> toggleActiveStatus(int keywordId, bool isActive);

  Future<void> deleteKeyword(int id);

  Future<void> bulkDeleteKeywords(List<int> ids);

  Future<RankObservation> recordObservation(RankObservation observation);

  Future<List<RankObservation>> getObservationsForKeyword(
    int keywordId, {
    String? searchEngine,
    int limit = 100,
  });

  Future<List<Map<String, dynamic>>> getCannibalizationAlerts(int websiteId);
}
