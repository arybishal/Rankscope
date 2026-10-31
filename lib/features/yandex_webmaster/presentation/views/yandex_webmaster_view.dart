import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../websites/presentation/controllers/websites_controller.dart';
import '../../domain/entities/yandex_metric.dart';
import '../controllers/yandex_controller.dart';

class YandexWebmasterView extends ConsumerStatefulWidget {
  const YandexWebmasterView({super.key});

  @override
  ConsumerState<YandexWebmasterView> createState() => _YandexWebmasterViewState();
}

class _YandexWebmasterViewState extends ConsumerState<YandexWebmasterView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);
    final isConfigured = ref.watch(yandexConfiguredProvider).value ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Yandex Webmaster', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Yandex Settings',
            onPressed: () => context.push('/settings'),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_outlined, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: AppSpacing.md),
                    const Text('No Website Selected', style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Please select or add a website from the Overview tab.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!isConfigured) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.travel_explore, size: 40, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Yandex Webmaster Not Connected', style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Configure your official Yandex OAuth Token in Settings to view impressions, clicks, and average positions directly from Yandex Search.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.vpn_key_outlined, size: 16),
                      label: const Text('Configure Yandex in Settings'),
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            );
          }

          final metricsAsync = ref.watch(yandexMetricsFutureProvider(activeWebsite.id!));
          final aggregatesAsync = ref.watch(yandexAggregatesFutureProvider(activeWebsite.id!));
          final syncState = ref.watch(yandexSyncNotifierProvider);

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(yandexMetricsFutureProvider(activeWebsite.id!));
              ref.invalidate(yandexAggregatesFutureProvider(activeWebsite.id!));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Information Disambiguation Banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Yandex Webmaster metrics (AVG_SHOW_POSITION) represent statistical averages across search impressions. They reflect real searcher visibility and are distinct from single-location manual SERP audits.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Host Mapping & Sync Action Bar
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeWebsite.label,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeWebsite.yandexHostId != null
                                  ? 'Host ID: ${activeWebsite.yandexHostId}'
                                  : 'Host: Auto-mapping to verified domain (${activeWebsite.domain})',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: syncState.isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sync, size: 15),
                        label: Text(
                          syncState.isSyncing ? 'Syncing...' : 'Sync Yandex',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: syncState.isSyncing
                            ? null
                            : () async {
                                final host = activeWebsite.yandexHostId ??
                                    'https:${activeWebsite.domain}:443';
                                final synced = await ref
                                    .read(yandexSyncNotifierProvider.notifier)
                                    .syncSiteMetrics(
                                      websiteId: activeWebsite.id!,
                                      hostId: host,
                                    );
                                if (context.mounted && synced != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Synced $synced queries from Yandex Webmaster.'),
                                      backgroundColor: AppColors.rankGain,
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Aggregates KPI Row
                aggregatesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (agg) {
                    final impressions = agg['total_impressions'] as int? ?? 0;
                    final clicks = agg['total_clicks'] as int? ?? 0;
                    final ctr = (agg['average_ctr'] as num?)?.toDouble() ?? 0.0;
                    final avgPos = (agg['average_position'] as num?)?.toDouble() ?? 0.0;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                isDark: isDark,
                                title: 'Yandex Impressions',
                                value: NumberFormat.compact().format(impressions),
                                subtitle: 'Search shows',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildMetricTile(
                                isDark: isDark,
                                title: 'Yandex Clicks',
                                value: NumberFormat.compact().format(clicks),
                                subtitle: 'Total visits',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                isDark: isDark,
                                title: 'Average CTR',
                                value: '${(ctr * 100).toStringAsFixed(1)}%',
                                subtitle: 'Click-through rate',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildMetricTile(
                                isDark: isDark,
                                title: 'Average Position',
                                value: avgPos > 0 ? avgPos.toStringAsFixed(1) : '—',
                                subtitle: 'Weighted show position',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    );
                  },
                ),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search Yandex queries...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Query List
                metricsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error loading Yandex data: $e')),
                  data: (metrics) {
                    final filtered = _searchQuery.isEmpty
                        ? metrics
                        : metrics
                            .where((m) => m.query.toLowerCase().contains(_searchQuery))
                            .toList();

                    if (filtered.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            metrics.isEmpty
                                ? 'No Yandex Webmaster query data cached yet.\nTap "Sync Yandex" above to ingest search queries.'
                                : 'No queries matching "$_searchQuery".',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final m = filtered[index];
                        return _buildQueryRow(isDark, m);
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

  Widget _buildMetricTile({
    required bool isDark,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelSmall.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.metricMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryRow(bool isDark, YandexMetric m) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.darkBorderMedium : const Color(0xFFFECACA),
              ),
            ),
            child: Text(
              m.averagePosition > 0 ? m.averagePosition.toStringAsFixed(1) : '—',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${NumberFormat.compact().format(m.impressions)} shows',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${m.clicks} clicks',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'CTR: ${(m.ctr * 100).toStringAsFixed(1)}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    if (m.averageClickPosition != null && m.averageClickPosition! > 0)
                      Text(
                        'Click pos: ${m.averageClickPosition!.toStringAsFixed(1)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
