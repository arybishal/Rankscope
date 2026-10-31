import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
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
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Status',
                onPressed: () {
                  ref
                      .read(bingSyncNotifierProvider.notifier)
                      .refreshStatus(active.domain);
                },
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

          final statusAsync = ref.watch(
            bingPropertyStatusProvider(activeWebsite.domain),
          );
          final metricsAsync = ref.watch(
            bingMetricsFutureProvider(activeWebsite.id!),
          );

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref
                  .read(bingSyncNotifierProvider.notifier)
                  .refreshStatus(activeWebsite.domain);
              await ref
                  .read(bingSyncNotifierProvider.notifier)
                  .syncWebsite(activeWebsite.id!, activeWebsite.domain);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Active Website Switcher Banner
                _ActiveWebsiteHeader(
                  activeWebsite: activeWebsite,
                  allWebsites: websites,
                ),
                const SizedBox(height: AppSpacing.md),

                // Bing Property Status Banner
                statusAsync.when(
                  loading: () => Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Verifying Bing property status...',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => _StatusCard(
                    status: BingVerificationStatus.connectionUnavailable,
                    title: 'Verification Check Failed',
                    subtitle: e.toString(),
                    onRetry: () {
                      ref
                          .read(bingSyncNotifierProvider.notifier)
                          .refreshStatus(activeWebsite.domain);
                    },
                  ),
                  data: (matchResult) {
                    return _BingStatusBanner(
                      activeWebsite: activeWebsite,
                      matchResult: matchResult,
                      isSyncing: syncState.isSyncing,
                      onSync: () => _handleSync(
                        context,
                        ref,
                        activeWebsite.id!,
                        activeWebsite.domain,
                      ),
                      onRefresh: () {
                        ref
                            .read(bingSyncNotifierProvider.notifier)
                            .refreshStatus(activeWebsite.domain);
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bing Search Query Insights Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Bing Search Query Insights',
                        style: AppTextStyles.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    statusAsync.maybeWhen(
                      data: (res) => res.isSyncAllowed
                          ? TextButton.icon(
                              onPressed: syncState.isSyncing
                                  ? null
                                  : () => _handleSync(
                                      context,
                                      ref,
                                      activeWebsite.id!,
                                      activeWebsite.domain,
                                    ),
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Sync Now'),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Metrics List
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
                              'Sync rankings and performance data directly from Bing Webmaster Tools for ${activeWebsite.domain}.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            statusAsync.maybeWhen(
                              data: (res) => res.isSyncAllowed
                                  ? AppPrimaryButton(
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
                                    )
                                  : OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Recheck Bing Status'),
                                      onPressed: () {
                                        ref
                                            .read(
                                              bingSyncNotifierProvider.notifier,
                                            )
                                            .refreshStatus(
                                              activeWebsite.domain,
                                            );
                                      },
                                    ),
                              orElse: () => const SizedBox.shrink(),
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
                                      '${m.clicks} clicks • ${m.impressions} impr. • ${(m.ctr * 100).toStringAsFixed(1)}% CTR',
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

class _ActiveWebsiteHeader extends ConsumerWidget {
  final Website activeWebsite;
  final List<Website> allWebsites;

  const _ActiveWebsiteHeader({
    required this.activeWebsite,
    required this.allWebsites,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: activeWebsite.id,
          isExpanded: true,
          dropdownColor: AppColors.surfacePrimary,
          items: allWebsites.map((w) {
            return DropdownMenuItem<int>(
              value: w.id,
              child: Row(
                children: [
                  Icon(
                    w.isCompetitor
                        ? Icons.shield_outlined
                        : Icons.check_circle_outline,
                    size: 16,
                    color: w.isCompetitor
                        ? AppColors.rankDrop
                        : AppColors.rankGain,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      w.label,
                      style: AppTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '(${w.domain})',
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newId) {
            if (newId != null) {
              ref.read(selectedWebsiteIdProvider.notifier).select(newId);
            }
          },
        ),
      ),
    );
  }
}

class _BingStatusBanner extends StatelessWidget {
  final Website activeWebsite;
  final BingPropertyMatchResult matchResult;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onRefresh;

  const _BingStatusBanner({
    required this.activeWebsite,
    required this.matchResult,
    required this.isSyncing,
    required this.onSync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    switch (matchResult.status) {
      case BingVerificationStatus.verifiedAndMatched:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), // light subtle green
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 20,
                    color: AppColors.rankGain,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'Verified and Matched',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Refresh Status',
                    onPressed: onRefresh,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Matched Property: ${matchResult.matchedBingUrl ?? activeWebsite.domain}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: isSyncing ? 'Syncing...' : 'Sync Search Analytics',
                  icon: const Icon(
                    Icons.cloud_sync_outlined,
                    size: 18,
                    color: AppColors.surfacePrimary,
                  ),
                  isLoading: isSyncing,
                  onPressed: onSync,
                ),
              ),
            ],
          ),
        );

      case BingVerificationStatus.locallyAddedNotVerified:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB), // subtle amber
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pending_actions_outlined,
                    size: 20,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'Added Locally, Not Verified in Bing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Recheck Verification',
                    onPressed: onRefresh,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Property "${matchResult.matchedBingUrl}" is listed in your Bing Webmaster account, but ownership verification is pending in Bing.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check Verification Status'),
              ),
            ],
          ),
        );

      case BingVerificationStatus.propertyNotFound:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.search_off_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'Bing Property Not Found',
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Refresh Properties',
                    onPressed: onRefresh,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Domain "${activeWebsite.domain}" does not match any registered site in your Bing Webmaster account.',
                style: AppTextStyles.bodySmall,
              ),
              if (matchResult.availableProperties.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Sites registered in your Bing account:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ...matchResult.availableProperties.map(
                  (prop) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          prop.isVerified
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                          size: 14,
                          color: prop.isVerified
                              ? AppColors.rankGain
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            prop.url,
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          prop.isVerified ? 'Verified' : 'Unverified',
                          style: TextStyle(
                            fontSize: 11,
                            color: prop.isVerified
                                ? AppColors.rankGain
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Bing Sites'),
              ),
            ],
          ),
        );

      case BingVerificationStatus.authFailed:
        return _StatusCard(
          status: matchResult.status,
          title: 'Authentication Failed',
          subtitle:
              matchResult.errorMessage ??
              'Your Bing API key is invalid or unauthorized.',
          actionLabel: 'Open Settings',
          onAction: () => context.push('/settings'),
        );

      case BingVerificationStatus.connectionUnavailable:
        return _StatusCard(
          status: matchResult.status,
          title: 'Connection Unavailable',
          subtitle: matchResult.errorMessage ?? 'Unable to connect to Bing Webmaster Tools. Check your internet connection.',
          onRetry: onRefresh,
        );

      case BingVerificationStatus.notConfigured:
        return _StatusCard(
          status: matchResult.status,
          title: 'Bing API Key Not Configured',
          subtitle: 'Add your personal Bing Webmaster API key in Settings to inspect search rankings and performance.',
          actionLabel: 'Configure in Settings',
          onAction: () => context.push('/settings'),
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  final BingVerificationStatus status;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onRetry;

  const _StatusCard({
    required this.status,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.borderSubtle;
    Color bgColor = AppColors.surfaceSecondary;
    IconData iconData = Icons.info_outline;
    Color iconColor = AppColors.textSecondary;

    if (status == BingVerificationStatus.authFailed) {
      borderColor = const Color(0xFFFECACA);
      bgColor = const Color(0xFFFEF2F2);
      iconData = Icons.lock_outline;
      iconColor = AppColors.rankDrop;
    } else if (status == BingVerificationStatus.connectionUnavailable) {
      borderColor = AppColors.borderSubtle;
      bgColor = AppColors.surfaceSecondary;
      iconData = Icons.cloud_off_outlined;
      iconColor = AppColors.textSecondary;
    } else if (status == BingVerificationStatus.notConfigured) {
      borderColor = AppColors.borderSubtle;
      bgColor = AppColors.surfaceSecondary;
      iconData = Icons.vpn_key_outlined;
      iconColor = AppColors.accent;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: status == BingVerificationStatus.authFailed
                        ? AppColors.rankDrop
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: onRetry,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.bodySmall),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
