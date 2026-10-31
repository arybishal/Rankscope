import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/search_console/presentation/controllers/gsc_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';

export '../controllers/gsc_controller.dart';
import 'package:rankscope/shared/widgets/cards/rank_metric_card.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';
import 'package:rankscope/shared/widgets/surfaces/glass_container.dart';

class SearchConsoleView extends ConsumerWidget {
  const SearchConsoleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);
    final syncState = ref.watch(searchPerformanceSyncProvider);

    return websitesState.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
        appBar: AppBar(
          title: const Text('Google Search Console', style: AppTextStyles.titleLarge),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
        appBar: AppBar(
          title: const Text('Google Search Console', style: AppTextStyles.titleLarge),
        ),
        body: Center(child: Text('Error: $err')),
      ),
      data: (websites) {
        final activeWebsite = websites.findActive(selectedSiteId);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
          appBar: AppBar(
            title: const Text(
              'Google Search Console',
              style: AppTextStyles.titleLarge,
            ),
            actions: [
              if (activeWebsite != null)
                IconButton(
                  icon: syncState.isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync),
                  tooltip: 'Sync GSC Data',
                  onPressed: syncState.isSyncing
                      ? null
                      : () async {
                          final res = await ref
                              .read(searchPerformanceSyncProvider.notifier)
                              .syncPerformance(
                                websiteId: activeWebsite.id!,
                                domain: activeWebsite.domain,
                              );
                          if (context.mounted && res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res.googleStatusMessage ??
                                      'Google Search Console synchronized.',
                                ),
                              ),
                            );
                          }
                        },
                ),
            ],
          ),
          body: activeWebsite == null
              ? const EmptyStateView(
                  icon: Icons.search,
                  title: 'No Website Selected',
                  description:
                      'Register a website on the Overview tab to view Google Search Console metrics.',
                )
              : _buildContent(context, ref, isDark, activeWebsite),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    dynamic activeWebsite,
  ) {
    final gscStatus = ref.watch(gscConnectionStatusProvider).value ??
        GscConnectionStatus.notConfigured();
    final metricsAsync = ref.watch(
      gscMetricsFutureProvider(activeWebsite.id!),
    );
    final aggregatesAsync = ref.watch(
      gscAggregatesFutureProvider(activeWebsite.id!),
    );

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(gscConnectionStatusProvider.notifier)
            .refreshStatus(verifyWithApi: true);
        await ref
            .read(searchPerformanceSyncProvider.notifier)
            .syncPerformance(
              websiteId: activeWebsite.id!,
              domain: activeWebsite.domain,
            );
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Connection Status Notification Banner if not connected
          if (!gscStatus.isConnected) ...[
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.travel_explore,
                        size: 20,
                        color: AppColors.engineGoogle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Google Search Console: ${gscStatus.label}',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    gscStatus.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.login, size: 16),
                        label: const Text('Connect with Google'),
                        onPressed: () async {
                          final res = await ref
                              .read(gscConnectionStatusProvider.notifier)
                              .connectGoogle();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res.isConnected
                                      ? 'Connected to Google Search Console!'
                                      : res.message,
                                ),
                                backgroundColor: res.isConnected
                                    ? AppColors.rankGain
                                    : AppColors.rankDrop,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/settings'),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkRankGainLight
                    : AppColors.rankGainLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.rankGain.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppColors.rankGain,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connected: ${gscStatus.userEmail ?? "Google Search Console API"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.rankGain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Disambiguation Alert Box
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Google Search Console average position is a statistical aggregate computed over impressions across search queries, devices, and dates. It is distinct from discrete point-in-time SERP rankings.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
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

              Text(
                'Top Search Queries',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
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
                    return GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_sync_outlined,
                            size: 40,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No Search Console Data Synced Yet',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect your Google Search Console account to pull verified organic search queries directly to your device.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!gscStatus.isConnected)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.login, size: 16),
                              label: const Text('Connect with Google'),
                              onPressed: () async {
                                final res = await ref
                                    .read(gscConnectionStatusProvider.notifier)
                                    .connectGoogle();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        res.isConnected
                                            ? 'Connected to Google Search Console!'
                                            : res.message,
                                      ),
                                      backgroundColor: res.isConnected
                                          ? AppColors.rankGain
                                          : AppColors.rankDrop,
                                    ),
                                  );
                                }
                              },
                            )
                          else
                            ElevatedButton.icon(
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Sync Search Console Data'),
                              onPressed: () => ref
                                  .read(searchPerformanceSyncProvider.notifier)
                                  .syncPerformance(
                                    websiteId: activeWebsite.id!,
                                    domain: activeWebsite.domain,
                                  ),
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
                      return GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.query,
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.clicks} clicks • ${m.impressions} impr.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
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
                                color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.badgeRadius,
                                ),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                                ),
                              ),
                              child: Text(
                                'Avg #${m.averagePosition.toStringAsFixed(1)}',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
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
          ),
        );
  }
}
