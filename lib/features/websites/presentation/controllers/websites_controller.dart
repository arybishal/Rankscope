import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/websites_repository_impl.dart';
import '../../domain/entities/website.dart';
import '../../domain/repositories/websites_repository.dart';

final websitesRepositoryProvider = Provider<WebsitesRepository>((ref) {
  return WebsitesRepositoryImpl();
});

class SelectedWebsiteIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedWebsiteIdProvider = NotifierProvider<SelectedWebsiteIdNotifier, int?>(SelectedWebsiteIdNotifier.new);

class WebsitesNotifier extends AsyncNotifier<List<Website>> {
  @override
  Future<List<Website>> build() async {
    final repo = ref.watch(websitesRepositoryProvider);
    return repo.getWebsites();
  }

  Future<void> loadWebsites() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(websitesRepositoryProvider);
      return repo.getWebsites();
    });
  }

  Future<Website?> addWebsite({
    required String domain,
    required String label,
    bool isCompetitor = false,
    String? gscPropertyId,
    String? bingSiteUrl,
    String? notes,
  }) async {
    final repo = ref.read(websitesRepositoryProvider);
    final now = DateTime.now();
    final newSite = Website(
      domain: domain,
      label: label,
      isCompetitor: isCompetitor,
      gscPropertyId: gscPropertyId,
      bingSiteUrl: bingSiteUrl,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    final created = await repo.addWebsite(newSite);
    await loadWebsites();
    return created;
  }

  Future<void> deleteWebsite(int id) async {
    final repo = ref.read(websitesRepositoryProvider);
    await repo.deleteWebsite(id);
    await loadWebsites();
  }
}

final websitesProvider = AsyncNotifierProvider<WebsitesNotifier, List<Website>>(WebsitesNotifier.new);
