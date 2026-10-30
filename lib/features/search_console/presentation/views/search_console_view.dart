import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/search_console/data/datasources/local_gsc_datasource.dart';
import 'package:rankscope/features/search_console/domain/entities/gsc_metric.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/cards/rank_metric_card.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';

final localGscDatasourceProvider = Provider<LocalGscDatasource>((ref) {
  return LocalGscDatasource();
});

final gscMetricsFutureProvider = FutureProvider.family<List<GscMetric>, int>((
  ref,
  websiteId,
) async {
  final ds = ref.watch(localGscDatasourceProvider);
  return await ds.getMetrics(websiteId, limit: 100);
});

final gscAggregatesFutureProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, websiteId) async {
      final ds = ref.watch(localGscDatasourceProvider);
      return await ds.getAggregates(websiteId);
    });

class SearchConsoleView extends ConsumerWidget {
  const SearchConsoleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);

    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text(
          'Google Search Console',
          style: AppTextStyles.titleLarge,
        ),
      ),
      body: websitesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (websites) {
          final activeWebsite = websites.findActive(selectedSiteId);
          if (activeWebsite == null) {
            return const EmptyStateView(
              icon: Icons.search,
              title: 'No Website Selected',
              description: 'Register a website on the Dashboard tab to view Google Search Console metrics.',
            );
          }

          final metricsAsync = ref.watch(
            gscMetricsFutureProvider(activeWebsite.id!),
          );
          final aggregatesAsync = ref.watch(
            gscAggregatesFutureProvider(activeWebsite.id!),
          );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Mandatory Disambiguation Alert Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.borderMedium),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Google Search Console average position is a statistical aggregate computed over impressions and varies by personalization, date, and device. It is distinct from discrete point-in-time SERP rankings.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // KPI Aggregates
              aggregatesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Text('Error loading aggregates: $e'),
                data: (agg) {
                  final clicks = agg['total_clicks'] as int? ?? 0;
                  final impressions = agg['total_impressions'] as int? ?? 0;
                  final ctr = agg['avg_ctr'] as double? ?? 0.0;
                  final avgPos = agg['overall_avg_position'] as double? ?? 0.0;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RankMetricCard(
                              title: 'Clicks',
                              value: '$clicks',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: RankMetricCard(
                              title: 'Impressions',
                              value: '$impressions',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: RankMetricCard(
                              title: 'Avg. CTR',
                              value: '${(ctr * 100).toStringAsFixed(1)}%',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: RankMetricCard(
                              title: 'Avg. Position',
                              value: avgPos > 0
                                  ? avgPos.toStringAsFixed(1)
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              const Text(
                'Top Search Queries',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),

              metricsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (metrics) {
                  if (metrics.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.cloud_sync_outlined,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No Search Console Data Synced Yet',
                            style: AppTextStyles.labelLarge,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Connect your Google Search Console account via Settings to pull verified organic search queries without any middleman.',
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
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final m = metrics[index];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePrimary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.cardRadius,
                          ),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.query,
                                    style: AppTextStyles.labelLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.clicks} clicks • ${m.impressions} impr.',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.badgeRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
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
