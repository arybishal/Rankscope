import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/utils/date_formatter.dart';
import 'package:rankscope/core/utils/url_validator.dart';
import 'package:rankscope/features/dashboard/presentation/controllers/dashboard_trend_controller.dart';
import 'package:rankscope/features/keywords/data/services/keyword_analysis_service.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/keywords/presentation/views/keyword_details_view.dart';
import 'package:rankscope/features/reporting/data/generators/csv_report_generator.dart';
import 'package:rankscope/features/reporting/data/generators/pdf_report_generator.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/cards/rank_metric_card.dart';
import 'package:rankscope/shared/widgets/charts/trend_line_chart.dart';
import 'package:rankscope/shared/widgets/dialogs/add_keyword_dialog.dart';
import 'package:rankscope/shared/widgets/dialogs/add_website_dialog.dart';
import 'package:rankscope/shared/widgets/dialogs/log_rank_dialog.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';
import 'package:rankscope/shared/widgets/surfaces/glass_container.dart';
import 'package:share_plus/share_plus.dart';

final googleConfiguredProvider = FutureProvider<bool>((ref) async {
  final service = SearchPerformanceSyncService();
  return await service.isGoogleConfigured();
});

final bingConfiguredProvider = FutureProvider<bool>((ref) async {
  final service = SearchPerformanceSyncService();
  return await service.isBingConfigured();
});

final yandexConfiguredProvider = FutureProvider<bool>((ref) async {
  final service = SearchPerformanceSyncService();
  return await service.isYandexConfigured();
});

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('RankScope', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: Icon(
              Icons.language_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            tooltip: 'Manage Websites',
            onPressed: () => context.push('/websites'),
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            tooltip: 'Add Website',
            onPressed: () => _openAddWebsiteDialog(context),
          ),
        ],
      ),
      body: websitesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (websites) {
          final activeWebsite = websites.findActive(selectedSiteId);
          if (activeWebsite == null) {
            return EmptyStateView(
              icon: Icons.language,
              title: 'No Websites Tracked',
              description:
                  'Start by registering your primary website domain or a competitor to monitor.',
              actionLabel: 'Add Your First Website',
              onAction: () => _openAddWebsiteDialog(context),
            );
          }

          return _DashboardContent(
            website: activeWebsite,
            allWebsites: websites,
          );
        },
      ),
    );
  }

  void _openAddWebsiteDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddWebsiteDialog());
  }
}

enum _KeywordFilter {
  all,
  hasData,
  matchesTarget,
  differentPage,
  noData,
  paused,
}

enum _SortOption {
  bestGoogleRank,
  bestBingRank,
  bestYandexRank,
  mostImpressions,
  mostClicks,
  alphabetical,
  recentlyChecked,
}

class _DashboardContent extends ConsumerStatefulWidget {
  final Website website;
  final List<Website> allWebsites;

  const _DashboardContent({required this.website, required this.allWebsites});

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  String _selectedEngine = 'All'; // 'All', 'Google', 'Bing', 'Yandex'
  int _selectedDays = 28; // 7, 28, 90, custom
  DateTimeRange? _customDateRange;
  _KeywordFilter _filter = _KeywordFilter.all;
  _SortOption _sort = _SortOption.bestGoogleRank;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 10;
  bool _showInsights = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordsState = ref.watch(keywordsFamilyProvider(widget.website.id!));
    final syncState = ref.watch(searchPerformanceSyncProvider);
    final googleConfigured = ref.watch(googleConfiguredProvider).value ?? false;
    final bingConfigured = ref.watch(bingConfiguredProvider).value ?? false;
    final yandexConfigured = ref.watch(yandexConfiguredProvider).value ?? false;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref
            .read(keywordsFamilyProvider(widget.website.id!).notifier)
            .loadKeywords();
        ref.invalidate(googleConfiguredProvider);
        ref.invalidate(bingConfiguredProvider);
        ref.invalidate(yandexConfiguredProvider);
        ref.invalidate(dashboardTrendProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Website Selector Row
          _buildWebsiteSelectorRow(context, isDark),
          const SizedBox(height: AppSpacing.md),

          // 2. Search Performance Sync Banner & Engine Status
          _buildPerformanceSyncBanner(
            context,
            isDark,
            syncState,
            googleConfigured,
            bingConfigured,
            yandexConfigured,
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Search Engine Source Selector Tabs (All, Google, Bing, Yandex)
          _buildSearchEngineFilterTabs(isDark),
          const SizedBox(height: AppSpacing.sm),

          // 4. Date Range Selector (7d, 28d, 90d, Custom)
          _buildDateRangeSelectorRow(isDark),
          const SizedBox(height: AppSpacing.md),

          // 5. Performance Trend Graph (Historical Position Trends)
          _buildTrendGraphSection(isDark),
          const SizedBox(height: AppSpacing.md),

          // 6. Transparent Rules-Based SEO Insights Accordion
          keywordsState.maybeWhen(
            data: (kws) => _buildInsightsSection(context, isDark, kws),
            orElse: () => const SizedBox.shrink(),
          ),

          // 7. Summary KPIs & Keyword Table with Search, Filter & Pagination
          keywordsState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => Center(child: Text('Error loading keywords: $e')),
            data: (keywords) {
              return _buildKpiAndKeywordList(
                context,
                isDark,
                keywords,
                googleConfigured,
                bingConfigured,
                yandexConfigured,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteSelectorRow(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: widget.website.id,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                items: widget.allWebsites.map((w) {
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
                        Expanded(
                          flex: 3,
                          child: Text(
                            w.label,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 2,
                          child: Text(
                            '(${w.domain})',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    ref.read(selectedWebsiteIdProvider.notifier).select(id);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          icon: Icon(
            Icons.edit_outlined,
            size: 20,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          tooltip: 'Edit Website',
          onPressed: () => _openEditWebsiteDialog(context, widget.website),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: AppColors.rankDrop,
          ),
          tooltip: 'Delete Website',
          onPressed: () => _confirmDeleteWebsite(context, ref, widget.website),
        ),
      ],
    );
  }

  Widget _buildPerformanceSyncBanner(
    BuildContext context,
    bool isDark,
    SearchPerformanceSyncState syncState,
    bool googleConfigured,
    bool bingConfigured,
    bool yandexConfigured,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 20,
                color: isDark ? AppColors.darkAccent : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Performance Sync',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Correlate saved keywords with live search query data',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: syncState.isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(
                  syncState.isSyncing ? 'Syncing...' : 'Sync Performance',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: syncState.isSyncing
                    ? null
                    : () async {
                        final res = await ref
                            .read(searchPerformanceSyncProvider.notifier)
                            .syncPerformance(
                              websiteId: widget.website.id!,
                              domain: widget.website.domain,
                            );
                        if (context.mounted && res != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sync completed: ${res.matchedKeywords} of ${res.totalKeywords} keywords matched (${res.googleQueriesAvailable} GSC / ${res.bingQueriesAvailable} Bing / ${res.yandexQueriesAvailable} Yandex queries)',
                              ),
                              backgroundColor: AppColors.accent,
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 8),
          // Connection Status Pills
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildConnectionStatusChip(
                isDark: isDark,
                engine: 'Google Search Console',
                isConnected: googleConfigured,
                icon: Icons.search,
              ),
              _buildConnectionStatusChip(
                isDark: isDark,
                engine: 'Bing Webmaster',
                isConnected: bingConfigured,
                icon: Icons.travel_explore,
              ),
              _buildConnectionStatusChip(
                isDark: isDark,
                engine: 'Yandex Webmaster',
                isConnected: yandexConfigured,
                icon: Icons.travel_explore_outlined,
              ),
            ],
          ),
          if (syncState.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              syncState.errorMessage!,
              style: const TextStyle(fontSize: 11, color: AppColors.rankDrop),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionStatusChip({
    required bool isDark,
    required String engine,
    required bool isConnected,
    required IconData icon,
  }) {
    final activeBg = isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
    final inactiveBg = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF1F5F9);
    final activeBorder = isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0);
    final inactiveBorder = isDark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1);
    final activeColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isConnected ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isConnected ? activeBorder : inactiveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isConnected ? activeColor : inactiveColor),
          const SizedBox(width: 4),
          Text(
            '$engine: ${isConnected ? 'Connected' : 'Not Configured'}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isConnected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEngineFilterTabs(bool isDark) {
    return Row(
      children: [
        _buildEngineChip(isDark, 'All', 'All', Icons.apps),
        const SizedBox(width: 4),
        _buildEngineChip(isDark, 'Google', 'Google', Icons.search),
        const SizedBox(width: 4),
        _buildEngineChip(isDark, 'Bing', 'Bing', Icons.travel_explore),
        const SizedBox(width: 4),
        _buildEngineChip(isDark, 'Yandex', 'Yandex', Icons.travel_explore_outlined),
      ],
    );
  }

  Widget _buildEngineChip(bool isDark, String label, String value, IconData icon) {
    final isSelected = _selectedEngine == value;
    final activeBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
    final inactiveBg = isDark ? AppColors.darkCard : AppColors.surfaceSecondary;
    final activeBorder = isDark ? const Color(0xFF3B82F6) : AppColors.accent;
    final inactiveBorder = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final activeTextColor = isDark ? Colors.white : AppColors.accent;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedEngine = value;
          _currentPage = 1;
        }),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isSelected ? activeBorder : inactiveBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeTextColor : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? activeTextColor
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelectorRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Date Range:',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildDateRangeChip(isDark, '7D', 7),
            const SizedBox(width: 4),
            _buildDateRangeChip(isDark, '28D', 28),
            const SizedBox(width: 4),
            _buildDateRangeChip(isDark, '90D', 90),
            const SizedBox(width: 4),
            _buildCustomDateRangeChip(isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangeChip(bool isDark, String label, int days) {
    final isSelected = _selectedDays == days && _customDateRange == null;
    return InkWell(
      onTap: () => setState(() {
        _selectedDays = days;
        _customDateRange = null;
      }),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2563EB) : AppColors.accent)
              : (isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF3B82F6) : AppColors.accent)
                : (isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateRangeChip(bool isDark) {
    final isSelected = _customDateRange != null;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now,
          initialDateRange: _customDateRange ??
              DateTimeRange(
                start: now.subtract(Duration(days: _selectedDays)),
                end: now,
              ),
        );
        if (picked != null) {
          setState(() {
            _customDateRange = picked;
            _selectedDays = picked.duration.inDays.clamp(1, 365);
          });
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2563EB) : AppColors.accent)
              : (isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF3B82F6) : AppColors.accent)
                : (isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle),
          ),
        ),
        child: Text(
          _customDateRange != null
              ? '${DateFormat('M/d').format(_customDateRange!.start)}-${DateFormat('M/d').format(_customDateRange!.end)}'
              : 'Custom',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendGraphSection(bool isDark) {
    final trendAsync = ref.watch(
      dashboardTrendProvider(
        TrendQueryArgs(
          websiteId: widget.website.id!,
          days: _selectedDays,
          engine: _selectedEngine,
        ),
      ),
    );

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Performance Trend (Average Position)',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_selectedDays Days',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          trendAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => SizedBox(
              height: 160,
              child: Center(child: Text('Error plotting trend: $e')),
            ),
            data: (seriesList) {
              return TrendLineChart(
                series: seriesList,
                height: 160,
                invertYAxis: true, // SERP Rank: 1 is top
                yAxisSuffix: ' pos',
                emptyMessage:
                    'No historical ranking observations in the past $_selectedDays days.\nSync performance or log checks to populate trend curves.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(
    BuildContext context,
    bool isDark,
    List<Keyword> keywords,
  ) {
    final analysisService = const KeywordAnalysisService();
    final insights = analysisService.generateInsights(
      keywords: keywords,
      observationsByKeywordId: {},
      timeFrameLabel: 'Last $_selectedDays Days',
    );

    if (insights.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showInsights = !_showInsights),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SEO Intelligence & Opportunities (${insights.length})',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _showInsights ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (_showInsights) ...[
            const SizedBox(height: 8),
            Text(
              'Transparent, rules-based detections derived directly from search console data.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            ...insights.take(4).map((ins) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSecondary : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(ins.icon, size: 16, color: ins.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ins.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: ins.color,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  ins.searchEngine,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ins.description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Data Basis: ${ins.dataBasis}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiAndKeywordList(
    BuildContext context,
    bool isDark,
    List<Keyword> allKeywords,
    bool googleConfigured,
    bool bingConfigured,
    bool yandexConfigured,
  ) {
    final total = allKeywords.length;
    final withData = allKeywords.where((k) {
      if (_selectedEngine == 'Google') return k.hasGoogleData;
      if (_selectedEngine == 'Bing') return k.hasBingData;
      if (_selectedEngine == 'Yandex') return k.hasYandexData;
      return k.hasPerformanceData;
    }).length;

    // Calculate aggregated metrics for active engine
    int totalImpressions = 0;
    int totalClicks = 0;
    double avgPosSum = 0.0;
    int rankedKeywordsCount = 0;

    for (final kw in allKeywords) {
      if (_selectedEngine == 'Google') {
        totalImpressions += kw.googleImpressions;
        totalClicks += kw.googleClicks;
        if (kw.googleAveragePosition != null && kw.googleAveragePosition! > 0) {
          avgPosSum += kw.googleAveragePosition!;
          rankedKeywordsCount++;
        }
      } else if (_selectedEngine == 'Bing') {
        totalImpressions += kw.bingImpressions;
        totalClicks += kw.bingClicks;
        if (kw.bingAveragePosition != null && kw.bingAveragePosition! > 0) {
          avgPosSum += kw.bingAveragePosition!;
          rankedKeywordsCount++;
        }
      } else if (_selectedEngine == 'Yandex') {
        totalImpressions += kw.yandexImpressions;
        totalClicks += kw.yandexClicks;
        if (kw.yandexAveragePosition != null && kw.yandexAveragePosition! > 0) {
          avgPosSum += kw.yandexAveragePosition!;
          rankedKeywordsCount++;
        }
      } else {
        totalImpressions += kw.googleImpressions + kw.bingImpressions + kw.yandexImpressions;
        totalClicks += kw.googleClicks + kw.bingClicks + kw.yandexClicks;
        final avg = kw.googleAveragePosition ?? kw.bingAveragePosition ?? kw.yandexAveragePosition;
        if (avg != null && avg > 0) {
          avgPosSum += avg;
          rankedKeywordsCount++;
        }
      }
    }

    final overallAvgPos = rankedKeywordsCount > 0
        ? (avgPosSum / rankedKeywordsCount).toStringAsFixed(1)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1st Row of KPIs
        Row(
          children: [
            Expanded(
              child: RankMetricCard(
                title: 'Tracked Keywords',
                value: '$total',
                subtitle: _selectedEngine == 'All' ? 'All Engines' : _selectedEngine,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RankMetricCard(
                title: 'With Search Data',
                value: '$withData',
                subtitle: '$withData of $total keywords',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 2nd Row of KPIs: Avg Position & Clicks
        Row(
          children: [
            Expanded(
              child: RankMetricCard(
                title: 'Average Position',
                value: overallAvgPos,
                subtitle: rankedKeywordsCount > 0
                    ? 'Across $rankedKeywordsCount queries'
                    : 'No rank data yet',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RankMetricCard(
                title: 'Total Impressions',
                value: _formatNumber(totalImpressions),
                subtitle: '${_formatNumber(totalClicks)} clicks',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Actions Bar (PDF, CSV Export & Add Keyword)
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Export PDF'),
                  onPressed: allKeywords.isEmpty
                      ? null
                      : () => _exportPdf(context, widget.website, allKeywords),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: allKeywords.isEmpty
                      ? null
                      : () => _exportCsv(context, widget.website, allKeywords),
                ),
              ],
            ),
            Tooltip(
              message: 'Add Keyword',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Keyword'),
                onPressed: () => _openAddKeywordDialog(context, ref, widget.website.id!),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Search Input
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() {
            _searchQuery = val.trim().toLowerCase();
            _currentPage = 1;
          }),
          decoration: InputDecoration(
            hintText: 'Search keywords, landing pages, or target URLs...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _currentPage = 1;
                      });
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Horizontal Category Filter Chips & Sort Dropdown
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChoice('All', _KeywordFilter.all, total),
              const SizedBox(width: 6),
              _buildFilterChoice('Data Available', _KeywordFilter.hasData, withData),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Matches Target URL',
                _KeywordFilter.matchesTarget,
                allKeywords.where((k) => k.urlMatchStatus == 'matches_target').length,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Different Page Ranking',
                _KeywordFilter.differentPage,
                allKeywords.where((k) => k.urlMatchStatus == 'different_page').length,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice('No Data Yet', _KeywordFilter.noData, total - withData),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Paused',
                _KeywordFilter.paused,
                allKeywords.where((k) => !k.isActive).length,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Filter and Sort Summary Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Keyword Rankings',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<_SortOption>(
                value: _sort,
                dropdownColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                items: [
                  const DropdownMenuItem(
                    value: _SortOption.bestGoogleRank,
                    child: Text('Sort: Best Google Rank'),
                  ),
                  const DropdownMenuItem(
                    value: _SortOption.bestBingRank,
                    child: Text('Sort: Best Bing Rank'),
                  ),
                  const DropdownMenuItem(
                    value: _SortOption.bestYandexRank,
                    child: Text('Sort: Best Yandex Rank'),
                  ),
                  const DropdownMenuItem(
                    value: _SortOption.mostImpressions,
                    child: Text('Sort: Most Impressions'),
                  ),
                  const DropdownMenuItem(
                    value: _SortOption.mostClicks,
                    child: Text('Sort: Most Clicks'),
                  ),
                  const DropdownMenuItem(
                    value: _SortOption.alphabetical,
                    child: Text('Sort: Alphabetical'),
                  ),
                  const DropdownMenuItem(
                    value: _SortOption.recentlyChecked,
                    child: Text('Sort: Recently Checked'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sort = val);
                },
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkAccent : AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Filtered, Sorted, and Paginated Keyword Ranking Items
        _buildKeywordItemsList(
          context,
          isDark,
          allKeywords,
          googleConfigured,
          bingConfigured,
          yandexConfigured,
        ),
      ],
    );
  }

  Widget _buildFilterChoice(
    String label,
    _KeywordFilter filterValue,
    int count,
  ) {
    final isSelected = _filter == filterValue;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _filter = filterValue;
            _currentPage = 1;
          });
        }
      },
    );
  }

  Widget _buildKeywordItemsList(
    BuildContext context,
    bool isDark,
    List<Keyword> keywords,
    bool googleConfigured,
    bool bingConfigured,
    bool yandexConfigured,
  ) {
    // 1. Filter
    List<Keyword> filtered = keywords.where((k) {
      if (_searchQuery.isNotEmpty) {
        final matchesText = k.keywordText.toLowerCase().contains(_searchQuery);
        final matchesGoogleUrl =
            k.googleRankingUrl?.toLowerCase().contains(_searchQuery) ?? false;
        final matchesBingUrl =
            k.bingRankingUrl?.toLowerCase().contains(_searchQuery) ?? false;
        final matchesYandexUrl =
            k.yandexRankingUrl?.toLowerCase().contains(_searchQuery) ?? false;
        final matchesTarget =
            k.targetUrl?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchesText &&
            !matchesGoogleUrl &&
            !matchesBingUrl &&
            !matchesYandexUrl &&
            !matchesTarget) {
          return false;
        }
      }

      switch (_filter) {
        case _KeywordFilter.all:
          return true;
        case _KeywordFilter.hasData:
          return k.hasPerformanceData;
        case _KeywordFilter.matchesTarget:
          return k.urlMatchStatus == 'matches_target';
        case _KeywordFilter.differentPage:
          return k.urlMatchStatus == 'different_page';
        case _KeywordFilter.noData:
          return !k.hasPerformanceData;
        case _KeywordFilter.paused:
          return !k.isActive;
      }
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      switch (_sort) {
        case _SortOption.bestGoogleRank:
          final posA = a.googleAveragePosition ?? 999.0;
          final posB = b.googleAveragePosition ?? 999.0;
          return posA.compareTo(posB);
        case _SortOption.bestBingRank:
          final posA = a.bingAveragePosition ?? 999.0;
          final posB = b.bingAveragePosition ?? 999.0;
          return posA.compareTo(posB);
        case _SortOption.bestYandexRank:
          final posA = a.yandexAveragePosition ?? 999.0;
          final posB = b.yandexAveragePosition ?? 999.0;
          return posA.compareTo(posB);
        case _SortOption.mostImpressions:
          final impA = a.googleImpressions + a.bingImpressions + a.yandexImpressions;
          final impB = b.googleImpressions + b.bingImpressions + b.yandexImpressions;
          return impB.compareTo(impA);
        case _SortOption.mostClicks:
          final clkA = a.googleClicks + a.bingClicks + a.yandexClicks;
          final clkB = b.googleClicks + b.bingClicks + b.yandexClicks;
          return clkB.compareTo(clkA);
        case _SortOption.alphabetical:
          return a.keywordText.toLowerCase().compareTo(b.keywordText.toLowerCase());
        case _SortOption.recentlyChecked:
          final dateA = a.lastCheckedAt ?? a.createdAt;
          final dateB = b.lastCheckedAt ?? b.createdAt;
          return dateB.compareTo(dateA);
      }
    });

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: EmptyStateView(
          icon: Icons.search_off,
          title: keywords.isEmpty ? 'No Keywords Added' : 'No Matching Keywords',
          description: keywords.isEmpty
              ? 'Add search queries you want to monitor for ${widget.website.domain}.'
              : 'No keywords match the active search query or filter selection.',
          actionLabel: keywords.isEmpty ? 'Add First Keyword' : null,
          onAction: keywords.isEmpty
              ? () => _openAddKeywordDialog(context, ref, widget.website.id!)
              : null,
        ),
      );
    }

    // 3. Pagination
    final totalPages = (filtered.length / _pageSize).ceil();
    final effectivePage = _currentPage.clamp(1, totalPages);
    final startIndex = (effectivePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(startIndex, endIndex);

    return Column(
      children: [
        ...pageItems.map((k) {
          return _KeywordRankingCard(
            keyword: k,
            website: widget.website,
            selectedEngine: _selectedEngine,
            googleConfigured: googleConfigured,
            bingConfigured: bingConfigured,
            yandexConfigured: yandexConfigured,
          );
        }),

        // Pagination Controls
        if (filtered.length > _pageSize) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${startIndex + 1}–$endIndex of ${filtered.length} keywords',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: effectivePage > 1
                          ? () => setState(() => _currentPage = effectivePage - 1)
                          : null,
                    ),
                    Text(
                      '$effectivePage / $totalPages',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: effectivePage < totalPages
                          ? () => setState(() => _currentPage = effectivePage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  Future<void> _exportPdf(
    BuildContext context,
    Website website,
    List<Keyword> keywords,
  ) async {
    try {
      final pdfBytes = await PdfReportGenerator.generatePdfReport(
        website: website,
        keywords: keywords,
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/RankScope_${website.domain}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(pdfBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'RankScope SEO Report for ${website.domain}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    Website website,
    List<Keyword> keywords,
  ) async {
    try {
      final csvBytes = CsvReportGenerator.generateKeywordsCsv(
        website: website,
        keywords: keywords,
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/RankScope_${website.domain}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsBytes(csvBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'RankScope Keywords CSV for ${website.domain}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  void _openAddKeywordDialog(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AddKeywordDialog(websiteId: websiteId),
    );
  }

  void _openEditWebsiteDialog(BuildContext context, Website website) {
    showDialog(
      context: context,
      builder: (_) => AddWebsiteDialog(initialWebsite: website),
    );
  }

  void _confirmDeleteWebsite(
    BuildContext context,
    WidgetRef ref,
    Website website,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Delete Website', style: AppTextStyles.titleLarge),
        content: Text(
          'Are you sure you want to delete "${website.label}" (${website.domain})?\n\n'
          'This will permanently delete this website, all tracked keywords, manual ranking records, and analytics. This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rankDrop,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(websitesProvider.notifier)
                    .deleteWebsite(website.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Website "${website.label}" deleted.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete website: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Rich Keyword Ranking Card displaying Google Search Console, Bing Webmaster,
/// and Yandex Webmaster performance data side-by-side with target URL matching.
class _KeywordRankingCard extends ConsumerWidget {
  final Keyword keyword;
  final Website website;
  final String selectedEngine;
  final bool googleConfigured;
  final bool bingConfigured;
  final bool yandexConfigured;

  const _KeywordRankingCard({
    required this.keyword,
    required this.website,
    required this.selectedEngine,
    required this.googleConfigured,
    required this.bingConfigured,
    required this.yandexConfigured,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showGoogle =
        selectedEngine == 'All' || selectedEngine.toLowerCase() == 'google';
    final showBing =
        selectedEngine == 'All' || selectedEngine.toLowerCase() == 'bing';
    final showYandex =
        selectedEngine == 'All' || selectedEngine.toLowerCase() == 'yandex';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  KeywordDetailsView(initialKeyword: keyword, website: website),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Keyword Query Text & Target URL
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                keyword.keywordText,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (!keyword.isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PAUSED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Metadata badges: Country, Device
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              keyword.targetCity != null
                                  ? '${keyword.targetCity}, ${keyword.targetCountry}'
                                  : keyword.targetCountry,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            Text('•', style: AppTextStyles.bodySmall),
                            Text(
                              keyword.device,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            if (keyword.tags.isNotEmpty) ...[
                              Text('•', style: AppTextStyles.bodySmall),
                              Text(
                                keyword.tags.join(', '),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.darkAccent : AppColors.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Expected Target URL
                        if (keyword.targetUrl != null &&
                            keyword.targetUrl!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '🎯 Target: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  keyword.targetUrl!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkAccent : AppColors.accent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                    onSelected: (val) {
                      switch (val) {
                        case 'log_serp':
                          showDialog(
                            context: context,
                            builder: (ctx) => LogRankDialog(
                              keyword: keyword,
                              websiteId: website.id!,
                            ),
                          );
                          break;
                        case 'edit':
                          showDialog(
                            context: context,
                            builder: (ctx) => AddKeywordDialog(
                              websiteId: website.id!,
                              initialKeyword: keyword,
                            ),
                          );
                          break;
                        case 'toggle_active':
                          ref
                              .read(
                                keywordsFamilyProvider(website.id!).notifier,
                              )
                              .toggleActive(keyword.id!, !keyword.isActive);
                          break;
                        case 'delete':
                          _confirmDeleteKeyword(
                            context,
                            ref,
                            keyword,
                            website.id!,
                          );
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'log_serp',
                        child: Row(
                          children: [
                            Icon(Icons.add_chart, size: 18),
                            SizedBox(width: 8),
                            Text('Log SERP Audit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Keyword'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_active',
                        child: Row(
                          children: [
                            Icon(
                              keyword.isActive
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              keyword.isActive
                                  ? 'Pause Tracking'
                                  : 'Resume Tracking',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.rankDrop,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: AppColors.rankDrop),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Search Engine Performance Cards
              if (showGoogle) ...[
                _buildEnginePerformanceBox(
                  context: context,
                  isDark: isDark,
                  engineName: 'Google Search Console',
                  dataLabel: 'Google Search Console Average Position',
                  icon: Icons.search,
                  brandColor: const Color(0xFF1D4ED8),
                  avgPosition: keyword.googleAveragePosition,
                  impressions: keyword.googleImpressions,
                  clicks: keyword.googleClicks,
                  ctr: keyword.googleCtr,
                  rankingUrl: keyword.googleRankingUrl,
                  targetUrl: keyword.targetUrl,
                  syncedAt: keyword.googleSyncedAt,
                  isConfigured: googleConfigured,
                ),
              ],

              if (showGoogle && showBing) const SizedBox(height: 8),

              if (showBing) ...[
                _buildEnginePerformanceBox(
                  context: context,
                  isDark: isDark,
                  engineName: 'Bing Webmaster',
                  dataLabel: 'Bing Average Position',
                  icon: Icons.travel_explore,
                  brandColor: const Color(0xFF0F766E),
                  avgPosition: keyword.bingAveragePosition,
                  impressions: keyword.bingImpressions,
                  clicks: keyword.bingClicks,
                  ctr: keyword.bingCtr,
                  rankingUrl: keyword.bingRankingUrl,
                  targetUrl: keyword.targetUrl,
                  syncedAt: keyword.bingSyncedAt,
                  isConfigured: bingConfigured,
                ),
              ],

              if ((showGoogle || showBing) && showYandex) const SizedBox(height: 8),

              if (showYandex) ...[
                _buildEnginePerformanceBox(
                  context: context,
                  isDark: isDark,
                  engineName: 'Yandex Webmaster',
                  dataLabel: 'Yandex Average Position',
                  icon: Icons.travel_explore_outlined,
                  brandColor: const Color(0xFFEA580C),
                  avgPosition: keyword.yandexAveragePosition,
                  impressions: keyword.yandexImpressions,
                  clicks: keyword.yandexClicks,
                  ctr: keyword.yandexCtr,
                  rankingUrl: keyword.yandexRankingUrl,
                  targetUrl: keyword.targetUrl,
                  syncedAt: keyword.yandexSyncedAt,
                  isConfigured: yandexConfigured,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnginePerformanceBox({
    required BuildContext context,
    required bool isDark,
    required String engineName,
    required String dataLabel,
    required IconData icon,
    required Color brandColor,
    required double? avgPosition,
    required int impressions,
    required int clicks,
    required double ctr,
    required String? rankingUrl,
    required String? targetUrl,
    required DateTime? syncedAt,
    required bool isConfigured,
  }) {
    final hasData = avgPosition != null && avgPosition > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Engine Header & Main Position Value
          Row(
            children: [
              Icon(icon, size: 14, color: brandColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dataLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: brandColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPositionBadgeBg(avgPosition, isDark),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getPositionBadgeBorder(avgPosition, isDark),
                    ),
                  ),
                  child: Text(
                    avgPosition.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _getPositionTextColor(avgPosition, isDark),
                    ),
                  ),
                )
              else if (!isConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Not Configured',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'No Impressions Yet',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),

          if (hasData) ...[
            const SizedBox(height: 6),
            // Row 2: Metrics (Clicks, Impressions, CTR, Synced)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMetricSnippet('Clicks', clicks.toString(), isDark),
                _buildMetricSnippet('Impressions', _formatNumber(impressions), isDark),
                _buildMetricSnippet(
                  'CTR',
                  '${(ctr * 100).toStringAsFixed(1)}%',
                  isDark,
                ),
                if (syncedAt != null)
                  Text(
                    'Synced ${DateFormatter.relativeTime(syncedAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),

            // Row 3: Observed Ranking URL
            if (rankingUrl != null && rankingUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 13,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: rankingUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ranking URL copied')),
                        );
                      },
                      child: Text(
                        rankingUrl,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Target URL match evaluation
              _buildTargetUrlMatchStatusBadge(targetUrl, rankingUrl, isDark),
            ],
          ] else ...[
            const SizedBox(height: 4),
            Text(
              !isConfigured
                  ? 'Connect $engineName to retrieve search queries, impressions, and average position.'
                  : 'This query has not received search visibility or impressions in the current date range.',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricSnippet(String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetUrlMatchStatusBadge(
    String? targetUrl,
    String? actualRankingUrl,
    bool isDark,
  ) {
    if (targetUrl == null || targetUrl.trim().isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'Target URL not specified',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
          ),
        ),
      );
    }

    final isMatch = UrlValidator.urlsMatch(targetUrl, actualRankingUrl);

    if (isMatch) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 10, color: Color(0xFF16A34A)),
            SizedBox(width: 3),
            Flexible(
              child: Text(
                'Matches Target Landing Page',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 10,
              color: Color(0xFFB45309),
            ),
            SizedBox(width: 3),
            Flexible(
              child: Text(
                'Different Page Ranking (Expected Target Not Ranking)',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB45309),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  Color _getPositionBadgeBg(double pos, bool isDark) {
    if (isDark) {
      if (pos <= 3.0) return const Color(0xFF451A03);
      if (pos <= 10.0) return const Color(0xFF172554);
      return AppColors.darkCard;
    }
    if (pos <= 3.0) return const Color(0xFFFEF9C3);
    if (pos <= 10.0) return const Color(0xFFEFF6FF);
    return const Color(0xFFF1F5F9);
  }

  Color _getPositionBadgeBorder(double pos, bool isDark) {
    if (isDark) {
      if (pos <= 3.0) return const Color(0xFFB45309);
      if (pos <= 10.0) return const Color(0xFF1E40AF);
      return AppColors.darkBorderSubtle;
    }
    if (pos <= 3.0) return const Color(0xFFFDE047);
    if (pos <= 10.0) return const Color(0xFFBFDBFE);
    return const Color(0xFFE2E8F0);
  }

  Color _getPositionTextColor(double pos, bool isDark) {
    if (isDark) {
      if (pos <= 3.0) return const Color(0xFFFBBF24);
      if (pos <= 10.0) return const Color(0xFF93C5FD);
      return AppColors.darkTextPrimary;
    }
    if (pos <= 3.0) return const Color(0xFF854D0E);
    if (pos <= 10.0) return const Color(0xFF1D4ED8);
    return AppColors.textPrimary;
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  void _confirmDeleteKeyword(
    BuildContext context,
    WidgetRef ref,
    Keyword kw,
    int websiteId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Delete Keyword', style: AppTextStyles.titleLarge),
        content: Text(
          'Are you sure you want to delete "${kw.keywordText}"?\n\n'
          'All associated rank movement history, URL observations, and alerts for this keyword will be permanently deleted.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rankDrop,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(keywordsFamilyProvider(websiteId).notifier)
                  .deleteKeyword(kw.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Keyword "${kw.keywordText}" deleted.'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
