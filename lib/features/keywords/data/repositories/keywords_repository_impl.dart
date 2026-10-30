import '../../../../core/errors/failures.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/repositories/keywords_repository.dart';
import '../datasources/local_keywords_datasource.dart';

/// Implementation of [KeywordsRepository].
class KeywordsRepositoryImpl implements KeywordsRepository {
  final LocalKeywordsDatasource _localDatasource;

  KeywordsRepositoryImpl({LocalKeywordsDatasource? localDatasource})
    : _localDatasource = localDatasource ?? LocalKeywordsDatasource();

  @override
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? tag,
  }) async {
    try {
      return await _localDatasource.getKeywordsByWebsite(
        websiteId,
        isActive: isActive,
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
  Future<Keyword> addKeyword(Keyword keyword) async {
    try {
      return await _localDatasource.insertKeyword(keyword);
    } catch (e) {
      throw DatabaseFailure('Failed to insert keyword: $e');
    }
  }

  @override
  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords) async {
    try {
      return await _localDatasource.insertKeywordsBatch(keywords);
    } catch (e) {
      throw DatabaseFailure('Failed to batch insert keywords: $e');
    }
  }

  @override
  Future<void> updateKeyword(Keyword keyword) async {
    try {
      await _localDatasource.updateKeyword(keyword);
    } catch (e) {
      throw DatabaseFailure('Failed to update keyword #${keyword.id}: $e');
    }
  }

  @override
  Future<void> updateKeywordPosition(int keywordId, int newPosition) async {
    try {
      await _localDatasource.updateKeywordPosition(keywordId, newPosition);
    } catch (e) {
      throw DatabaseFailure('Failed to update keyword position: $e');
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
}
