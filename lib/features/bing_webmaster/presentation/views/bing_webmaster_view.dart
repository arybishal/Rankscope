import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/bing_webmaster/data/datasources/local_bing_datasource.dart';
import 'package:rankscope/features/bing_webmaster/domain/entities/bing_metric.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';

final localBingDatasourceProvider = Provider<LocalBingDatasource>((ref) {
  return LocalBingDatasource();
});

final bingMetricsFutureProvider = FutureProvider.family<List<BingMetric>, int>((ref, websiteId) async {
  final ds = ref.watch(localBingDatasourceProvider);
  return await ds.getMetrics(websiteId, limit: 100);
});

class BingWebmasterView extends ConsumerWidget {
  const BingWebmasterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);

    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Bing Webmaster Tools', style: AppTextStyles.titleLarge),
      ),
      body: websitesState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (websites) {
          if (websites.isEmpty) {
            return const EmptyStateView(
              icon: Icons.language,
              title: 'No Website Selected',
              description: 'Register a website on the Dashboard tab to view Bing Webmaster statistics.',
            );
          }

          final activeId = selectedSiteId ?? websites.first.id!;
          final activeWebsite = websites.firstWhere((w) => w.id == activeId, orElse: () => websites.first);
          final metricsAsync = ref.watch(bingMetricsFutureProvider(activeWebsite.id!));

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Bing Webmaster Tools uses your free personal API key generated directly from Microsoft Bing Webmaster portal.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              const Text('Bing Search Query Insights', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),

              metricsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Text('Error: $e'),
                data: (metrics) {
                  if (metrics.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.travel_explore_outlined, size: 40, color: AppColors.textTertiary),
                          const SizedBox(height: 8),
                          const Text('No Bing Data Synced Yet', style: AppTextStyles.labelLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Add your Bing Webmaster API Key in Settings to ingest impressions and rankings for ${activeWebsite.domain}.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: metrics.length,
                    separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final m = metrics[index];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePrimary,
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.query, style: AppTextStyles.labelLarge),
                                  const SizedBox(height: 2),
                                  Text('${m.clicks} clicks • ${m.impressions} impr.', style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Text(
                                'Avg #${m.averagePosition.toStringAsFixed(1)}',
                                style: AppTextStyles.labelMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
