import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/bing_webmaster/presentation/controllers/bing_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/buttons/app_primary_button.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';

class BingWebmasterView extends ConsumerWidget {
  const BingWebmasterView({super.key});

  Future<void> _handleSync(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    String domain,
  ) async {
    final count = await ref
        .read(bingSyncNotifierProvider.notifier)
        .syncWebsite(websiteId, domain);

    if (!context.mounted) return;

    final syncState = ref.read(bingSyncNotifierProvider);
    if (syncState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncState.errorMessage!),
          backgroundColor: AppColors.rankDrop,
        ),
      );
    } else if (count != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Successfully synced $count Bing query metrics.'
                : 'Sync completed. No search queries recorded by Bing yet.',
          ),
          backgroundColor: AppColors.rankGain,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);
    final syncState = ref.watch(bingSyncNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text(
          'Bing Webmaster Tools',
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          websitesState.maybeWhen(
            data: (websites) {
              final active = websites.findActive(selectedSiteId);
              if (active == null || active.id == null) {
                return const SizedBox.shrink();
              }

              if (syncState.isSyncing) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                );
              }

              return IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sync Bing Data',
                onPressed: () =>
                    _handleSync(context, ref, active.id!, active.domain),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
              icon: Icons.language,
              title: 'No Website Selected',
              description: 'Register a website on the Dashboard tab to view Bing Webmaster statistics.',
            );
          }

          final metricsAsync = ref.watch(
            bingMetricsFutureProvider(activeWebsite.id!),
          );

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () => _handleSync(
              context,
              ref,
              activeWebsite.id!,
              activeWebsite.domain,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
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
                      Icon(
                        Icons.vpn_key_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
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

                const Text(
                  'Bing Search Query Insights',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),

                metricsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('Error: $e'),
                    ),
                  ),
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
                        child: Column(
                          children: [
                            const Icon(
                              Icons.travel_explore_outlined,
                              size: 40,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'No Bing Data Synced Yet',
                              style: AppTextStyles.labelLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Add your Bing Webmaster API Key in Settings to ingest impressions and rankings for ${activeWebsite.domain}.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppPrimaryButton(
                              label: 'Sync with Bing',
                              icon: const Icon(
                                Icons.sync,
                                size: 18,
                                color: AppColors.surfacePrimary,
                              ),
                              isLoading: syncState.isSyncing,
                              onPressed: () => _handleSync(
                                context,
                                ref,
                                activeWebsite.id!,
                                activeWebsite.domain,
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
                                  'Avg #${m.averagePosition > 0 ? m.averagePosition.toStringAsFixed(1) : '—'}',
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
            ),
          );
        },
      ),
    );
  }
}
