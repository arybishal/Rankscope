import '../entities/keyword.dart';

/// Repository interface for Keyword operations.
abstract class KeywordsRepository {
  Future<List<Keyword>> getKeywordsByWebsite(
    int websiteId, {
    bool? isActive,
    String? tag,
  });
  Future<Keyword?> getKeywordById(int id);
  Future<Keyword> addKeyword(Keyword keyword);
  Future<List<Keyword>> addKeywordsBatch(List<Keyword> keywords);
  Future<void> updateKeyword(Keyword keyword);
  Future<void> updateKeywordPosition(int keywordId, int newPosition);
  Future<void> deleteKeyword(int id);
}
