import '../../../../core/errors/failures.dart';
import '../../domain/repositories/keywords_repository.dart';
import '../datasources/local_keywords_datasource.dart';

/// Implementation of [KeywordsRepository].
class KeywordsRepositoryImpl implements KeywordsRepository {
  final LocalKeywordsDatasource _localDatasource;
  final SearchPerformanceSyncService _syncService;

  KeywordsRepositoryImpl({
    LocalKeywordsDatasource? localDatasource,
    SearchPerformanceSyncService? syncService,
  }) : _localDatasource = localDatasource ?? LocalKeywordsDatasource(),
       _syncService = syncService ?? SearchPerformanceSyncService();

  @override
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? searchEngine,
    String? tag,
  }) async {
    try {
      return await _localDatasource.getKeywordsByWebsite(
        websiteId,
        isActive: isActive,
        searchEngine: searchEngine,
        tag: tag,
      );
    } catch (e) {
      throw DatabaseFailure(
        'Failed to load keywords for website #$websiteId: $e',
      );
    }
  }

  @override
  Future<Keyword?> getKeywordById(int id) async {
    try {
      return await _localDatasource.getKeywordById(id);
    } catch (e) {
      throw DatabaseFailure('Failed to load keyword #$id: $e');
    }
  }

  @override
  Future<Keyword?> findDuplicateKeyword({
    required int websiteId,
    required String keywordText,
    required String searchEngine,
    required String targetCountry,
    String? targetCity,
    String language = 'en',
    String device = 'Desktop',
    int? excludeId,
  }) async {
    try {
      return await _localDatasource.findDuplicateKeyword(
        websiteId: websiteId,
        keywordText: keywordText,
        searchEngine: searchEngine,
        targetCountry: targetCountry,
        targetCity: targetCity,
        language: language,
        device: device,
        excludeId: excludeId,
      );
    } catch (e) {
      throw DatabaseFailure('Failed to check duplicate keyword: $e');
    }
  }

  @override
  Future<Keyword> addKeyword(Keyword keyword) async {
    try {
      final duplicate = await _localDatasource.findDuplicateKeyword(
        websiteId: keyword.websiteId,
        keywordText: keyword.keywordText,
        searchEngine: keyword.searchEngine,
        targetCountry: keyword.targetCountry,
        targetCity: keyword.targetCity,
        language: keyword.language,
        device: keyword.device,
      );
      if (duplicate != null) {
        throw const ValidationFailure(
          'This keyword is already being tracked with this search engine and location.',
        );
      }
      final inserted = await _localDatasource.insertKeyword(keyword);
      // Immediately correlate newly created keyword with existing search console data
      return await _syncService.correlateSingleKeyword(inserted);
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to insert keyword: $e');
    }
  }

  @override
  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords) async {
    try {
      final insertedList = await _localDatasource.insertKeywordsBatch(keywords);
      final List<Keyword> correlated = [];
      for (final kw in insertedList) {
        correlated.add(await _syncService.correlateSingleKeyword(kw));
      }
      return correlated;
    } catch (e) {
      throw DatabaseFailure('Failed to batch insert keywords: $e');
    }
  }

  @override
  Future<void> updateKeyword(Keyword keyword) async {
    try {
      final duplicate = await _localDatasource.findDuplicateKeyword(
        websiteId: keyword.websiteId,
        keywordText: keyword.keywordText,
        searchEngine: keyword.searchEngine,
        targetCountry: keyword.targetCountry,
        targetCity: keyword.targetCity,
        language: keyword.language,
        device: keyword.device,
        excludeId: keyword.id,
      );
      if (duplicate != null) {
        throw const ValidationFailure(
          'Another keyword with this exact configuration already exists.',
        );
      }
      await _localDatasource.updateKeyword(keyword);
      await _syncService.correlateSingleKeyword(keyword);
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Failed to update keyword #${keyword.id}: $e');
    }
  }

  @override
  Future<void> toggleActiveStatus(int keywordId, bool isActive) async {
    try {
      await _localDatasource.toggleActiveStatus(keywordId, isActive);
    } catch (e) {
      throw DatabaseFailure('Failed to toggle keyword status: $e');
    }
  }

  @override
  Future<void> deleteKeyword(int id) async {
    try {
      await _localDatasource.deleteKeyword(id);
    } catch (e) {
      throw DatabaseFailure('Failed to delete keyword #$id: $e');
    }
  }

  @override
  Future<void> bulkDeleteKeywords(List<int> ids) async {
    try {
      await _localDatasource.bulkDeleteKeywords(ids);
    } catch (e) {
      throw DatabaseFailure('Failed to bulk delete keywords: $e');
    }
  }

  @override
  Future<RankObservation> recordObservation(RankObservation observation) async {
    try {
      return await _localDatasource.recordObservation(observation);
    } catch (e) {
      throw DatabaseFailure('Failed to record rank observation: $e');
    }
  }

  @override
  Future<List<RankObservation>> getObservationsForKeyword(
    int keywordId, {
    String? searchEngine,
    int limit = 100,
  }) async {
    try {
      return await _localDatasource.getObservationsForKeyword(
        keywordId,
        searchEngine: searchEngine,
        limit: limit,
      );
    } catch (e) {
      throw DatabaseFailure('Failed to fetch rank observations: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCannibalizationAlerts(
    int websiteId,
  ) async {
    try {
      return await _localDatasource.getCannibalizationAlerts(websiteId);
    } catch (e) {
      throw DatabaseFailure('Failed to fetch cannibalization alerts: $e');
    }
  }

  @override
  Future<SearchSyncResult> syncPerformanceForWebsite({
    required int websiteId,
    required String domain,
    String? gscPropertyId,
    String? country,
    String? device,
    String? searchType,
  }) async {
    try {
      return await _syncService.syncPerformanceForWebsite(
        websiteId: websiteId,
        domain: domain,
        gscPropertyId: gscPropertyId,
        country: country,
        device: device,
        searchType: searchType,
      );
    } catch (e) {
      throw DatabaseFailure('Failed to sync search performance: $e');
    }
  }

  @override
  Future<Keyword> correlateSingleKeyword(Keyword keyword) async {
    try {
      return await _syncService.correlateSingleKeyword(keyword);
    } catch (e) {
      return keyword;
    }
  }
}
