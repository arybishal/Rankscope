import '../entities/website.dart';

/// Repository interface for Website domain operations.
abstract class WebsitesRepository {
  Future<List<Website>> getWebsites({bool? isCompetitor});
  Future<Website?> getWebsiteById(int id);
  Future<Website?> getWebsiteByDomain(
    String domain, {
    required bool isCompetitor,
  });
  Future<Website> addWebsite(Website website);
  Future<void> updateWebsite(Website website);
  Future<void> deleteWebsite(int id);
}
