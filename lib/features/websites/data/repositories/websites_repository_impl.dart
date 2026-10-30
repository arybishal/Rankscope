import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/website.dart';
import '../../domain/repositories/websites_repository.dart';
import '../datasources/local_websites_datasource.dart';

/// Implementation of [WebsitesRepository] utilizing local SQLite datasource.
class WebsitesRepositoryImpl implements WebsitesRepository {
  final LocalWebsitesDatasource _localDatasource;

  WebsitesRepositoryImpl({LocalWebsitesDatasource? localDatasource})
    : _localDatasource = localDatasource ?? LocalWebsitesDatasource();

  @override
  Future<List<Website>> getWebsites({bool? isCompetitor}) async {
    try {
      final websites = await _localDatasource.getWebsites(
        isCompetitor: isCompetitor,
      );
      return websites;
    } catch (e, st) {
      await AppLogger.instance.error(
        'Websites',
        'get_websites_failed',
        'Failed to retrieve websites',
        error: e,
        stackTrace: st,
      );
      throw DatabaseFailure('Failed to retrieve websites: $e');
    }
  }

  @override
  Future<Website?> getWebsiteById(int id) async {
    try {
      return await _localDatasource.getWebsiteById(id);
    } catch (e, st) {
      await AppLogger.instance.error(
        'Websites',
        'get_website_by_id_failed',
        'Failed to find website #$id',
        error: e,
        stackTrace: st,
      );
      throw DatabaseFailure('Failed to find website #$id: $e');
    }
  }

  @override
  Future<Website?> getWebsiteByDomain(
    String domain, {
    required bool isCompetitor,
  }) async {
    try {
      return await _localDatasource.getWebsiteByDomain(
        domain,
        isCompetitor: isCompetitor,
      );
    } catch (e, st) {
      await AppLogger.instance.error(
        'Websites',
        'get_website_by_domain_failed',
        'Failed to check domain $domain',
        error: e,
        stackTrace: st,
      );
      throw DatabaseFailure('Failed to check existing website domain: $e');
    }
  }

  @override
  Future<Website> addWebsite(Website website) async {
    try {
      final existing = await _localDatasource.getWebsiteByDomain(
        website.domain,
        isCompetitor: website.isCompetitor,
      );
      if (existing != null) {
        await AppLogger.instance.warning(
          'Websites',
          'duplicate_domain_blocked',
          'Domain already registered: ${website.domain}',
        );
        throw const ValidationFailure('This domain is already registered.');
      }
      final created = await _localDatasource.insertWebsite(website);
      await AppLogger.instance.info(
        'Websites',
        'website_added',
        'Successfully registered ${created.label} (${created.domain})',
      );
      return created;
    } on Failure {
      rethrow;
    } catch (e, st) {
      await AppLogger.instance.error(
        'Websites',
        'add_website_failed',
        'Failed to insert website: ${website.domain}',
        error: e,
        stackTrace: st,
      );
      throw DatabaseFailure('Failed to insert website: $e');
    }
  }

  @override
  Future<void> updateWebsite(Website website) async {
    try {
      await _localDatasource.updateWebsite(website);
      await AppLogger.instance.info(
        'Websites',
        'website_updated',
        'Updated website #${website.id} (${website.domain})',
      );
    } catch (e, st) {
      await AppLogger.instance.error(
        'Websites',
        'update_website_failed',
        'Failed to update website #${website.id}',
        error: e,
        stackTrace: st,
      );
      throw DatabaseFailure('Failed to update website: $e');
    }
  }

  @override
  Future<void> deleteWebsite(int id) async {
    try {
      await _localDatasource.deleteWebsite(id);
      await AppLogger.instance.info(
        'Websites',
        'website_deleted',
        'Deleted website #$id and cascading child records',
      );
    } catch (e, st) {
      await AppLogger.instance.error(
        'Websites',
        'delete_website_failed',
        'Failed to delete website #$id',
        error: e,
        stackTrace: st,
      );
      throw DatabaseFailure('Failed to delete website: $e');
    }
  }
}
