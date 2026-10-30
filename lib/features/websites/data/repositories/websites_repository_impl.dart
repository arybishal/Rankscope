import '../../../../core/errors/failures.dart';
import '../../domain/entities/website.dart';
import '../../domain/repositories/websites_repository.dart';
import '../datasources/local_websites_datasource.dart';
import '../models/website_model.dart';

/// Implementation of [WebsitesRepository] utilizing local SQLite datasource.
class WebsitesRepositoryImpl implements WebsitesRepository {
  final LocalWebsitesDatasource _localDatasource;

  WebsitesRepositoryImpl({LocalWebsitesDatasource? localDatasource})
      : _localDatasource = localDatasource ?? LocalWebsitesDatasource();

  @override
  Future<List<Website>> getWebsites({bool? isCompetitor}) async {
    try {
      final models = await _localDatasource.getWebsites(isCompetitor: isCompetitor);
      return models;
    } catch (e) {
      throw DatabaseFailure('Failed to retrieve websites: $e');
    }
  }

  @override
  Future<Website?> getWebsiteById(int id) async {
    try {
      return await _localDatasource.getWebsiteById(id);
    } catch (e) {
      throw DatabaseFailure('Failed to find website #$id: $e');
    }
  }

  @override
  Future<Website> addWebsite(Website website) async {
    try {
      final model = WebsiteModel.fromEntity(website);
      return await _localDatasource.insertWebsite(model);
    } catch (e) {
      throw DatabaseFailure('Failed to insert website: $e');
    }
  }

  @override
  Future<void> updateWebsite(Website website) async {
    try {
      final model = WebsiteModel.fromEntity(website);
      await _localDatasource.updateWebsite(model);
    } catch (e) {
      throw DatabaseFailure('Failed to update website: $e');
    }
  }

  @override
  Future<void> deleteWebsite(int id) async {
    try {
      await _localDatasource.deleteWebsite(id);
    } catch (e) {
      throw DatabaseFailure('Failed to delete website: $e');
    }
  }
}
