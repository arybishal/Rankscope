import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/dialogs/alert_settings_dialog.dart';
import '../../../../shared/widgets/feedback/empty_state_view.dart';
import '../../../../shared/widgets/surfaces/glass_container.dart';
import '../../../keywords/data/services/keyword_analysis_service.dart';
import '../../../keywords/presentation/controllers/keywords_controller.dart';
import '../../../websites/presentation/controllers/websites_controller.dart';

enum _AnalysisTab { insights, cannibalization, alerts }

class AnalysisView extends ConsumerStatefulWidget {
  const AnalysisView({super.key});

  @override
  ConsumerState<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends ConsumerState<AnalysisView> {
  _AnalysisTab _activeTab = _AnalysisTab.insights;
  String _selectedEngine = 'All'; // All, Google, Bing, Yandex
  InsightType? _selectedCategory; // null = all
  String _timeRange = 'Last 28 Days';
  String _alertSeverityFilter = 'all'; // all, unread, critical, warning, info
  CannibalizationConfidence? _cannibalConfidenceFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('SEO Intelligence & Analysis', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            tooltip: 'Alert Preferences & Notifications',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AlertSettingsDialog(),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.language_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            tooltip: 'Switch Website',
            onPressed: () => context.push('/websites'),
          ),
        ],
      ),
      body: websitesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading websites: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (websites) {
          final activeWebsite = websites.findActive(selectedSiteId);
          if (activeWebsite == null) {
            return EmptyStateView(
              icon: Icons.language,
              title: 'No Website Selected',
              description: 'Select or add a website to view transparent SEO intelligence analysis.',
              actionLabel: 'Manage Websites',
              onAction: () => context.push('/websites'),
            );
          }

          return _AnalysisContent(
            website: activeWebsite,
            allWebsites: websites,
            activeTab: _activeTab,
            selectedEngine: _selectedEngine,
            selectedCategory: _selectedCategory,
            timeRange: _timeRange,
            alertSeverityFilter: _alertSeverityFilter,
            cannibalConfidenceFilter: _cannibalConfidenceFilter,
            onTabChanged: (tab) => setState(() => _activeTab = tab),
            onEngineChanged: (e) => setState(() => _selectedEngine = e),
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
            onTimeRangeChanged: (t) => setState(() => _timeRange = t),
            onAlertFilterChanged: (f) => setState(() => _alertSeverityFilter = f),
            onCannibalFilterChanged: (c) => setState(() => _cannibalConfidenceFilter = c),
          );
        },
      ),
    );
  }
}

class _AnalysisContent extends ConsumerWidget {
  final Website website;
  final List<Website> allWebsites;
  final _AnalysisTab activeTab;
  final String selectedEngine;
  final InsightType? selectedCategory;
  final String timeRange;
  final String alertSeverityFilter;
  final CannibalizationConfidence? cannibalConfidenceFilter;
  final ValueChanged<_AnalysisTab> onTabChanged;
  final ValueChanged<String> onEngineChanged;
  final ValueChanged<InsightType?> onCategoryChanged;
  final ValueChanged<String> onTimeRangeChanged;
  final ValueChanged<String> onAlertFilterChanged;
  final ValueChanged<CannibalizationConfidence?> onCannibalFilterChanged;

  const _AnalysisContent({
    required this.website,
    required this.allWebsites,
    required this.activeTab,
    required this.selectedEngine,
    required this.selectedCategory,
    required this.timeRange,
    required this.alertSeverityFilter,
    required this.cannibalConfidenceFilter,
    required this.onTabChanged,
    required this.onEngineChanged,
    required this.onCategoryChanged,
    required this.onTimeRangeChanged,
    required this.onAlertFilterChanged,
    required this.onCannibalFilterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordsState = ref.watch(keywordsFamilyProvider(website.id!));
    final alertsState = ref.watch(rankingAlertsFamilyProvider(website.id!));
    final cannibalFindingsState =
        ref.watch(cannibalizationFindingsFamilyProvider(website.id!));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref
            .read(keywordsFamilyProvider(website.id!).notifier)
            .loadKeywords();
        ref.invalidate(rankingAlertsFamilyProvider(website.id!));
        ref.invalidate(cannibalizationFindingsFamilyProvider(website.id!));
      },
      child: keywordsState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading analysis: $err',
              style: AppTextStyles.bodyMedium),
        ),
        data: (keywords) {
          if (keywords.isEmpty) {
            return EmptyStateView(
              icon: Icons.insights_outlined,
              title: 'No Keywords Tracked',
              description:
                  'Add keywords or sync performance data to generate SEO intelligence insights.',
              actionLabel: 'Go to Overview',
              onAction: () => context.go('/dashboard'),
            );
          }

          // Build observations map from keyword history
          final Map<int, List<RankObservation>> obsMap = {};
          for (final kw in keywords) {
            final List<RankObservation> list = [];
            if (kw.previousPosition != null && kw.latestPosition != null) {
              list.add(
                RankObservation(
                  keywordId: kw.id!,
                  websiteId: website.id!,
                  searchEngine: kw.searchEngine,
                  position: kw.previousPosition!,
                  rankingUrl: kw.targetUrl,
                  recordedAt:
                      DateTime.now().subtract(const Duration(days: 14)),
                  source: 'historical',
                ),
              );
              list.add(
                RankObservation(
                  keywordId: kw.id!,
                  websiteId: website.id!,
                  searchEngine: kw.searchEngine,
                  position: kw.latestPosition!,
                  rankingUrl: kw.googleRankingUrl ??
                      kw.bingRankingUrl ??
                      kw.yandexRankingUrl ??
                      kw.targetUrl,
                  recordedAt: DateTime.now(),
                  source: 'latest',
                ),
              );
            }
            obsMap[kw.id!] = list;
          }

          // Generate insights
          const service = KeywordAnalysisService();
          List<KeywordInsight> insights = service.generateInsights(
            keywords: keywords,
            observationsByKeywordId: obsMap,
            timeFrameLabel: timeRange,
          );

          if (selectedEngine != 'All') {
            insights = insights.where((ins) {
              final eng = ins.searchEngine.toLowerCase();
              return eng.contains(selectedEngine.toLowerCase());
            }).toList();
          }

          if (selectedCategory != null) {
            insights =
                insights.where((ins) => ins.type == selectedCategory).toList();
          }

          final cannibalFindings = cannibalFindingsState.value ?? [];
          final alerts = alertsState.value ?? [];
          final unreadAlerts = alerts.where((a) => !a.isRead).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 1. Website Switcher Header
              _buildWebsiteHeader(context, isDark, ref),
              const SizedBox(height: AppSpacing.md),

              // 2. Intelligence Navigation Tabs
              _buildTabsRow(
                context,
                isDark,
                insightsCount: insights.length,
                cannibalCount: cannibalFindings.length,
                alertsCount: unreadAlerts > 0 ? unreadAlerts : alerts.length,
                hasUnreadAlerts: unreadAlerts > 0,
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Tab Specific Views
              if (activeTab == _AnalysisTab.insights) ...[
                _buildInsightsTab(context, isDark, insights),
              ] else if (activeTab == _AnalysisTab.cannibalization) ...[
                _buildCannibalizationTab(context, isDark, cannibalFindings),
              ] else ...[
                _buildAlertsTab(context, isDark, alerts, ref),
              ],
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  // --- Sub-navigation Tabs ---

  Widget _buildTabsRow(
    BuildContext context,
    bool isDark, {
    required int insightsCount,
    required int cannibalCount,
    required int alertsCount,
    required bool hasUnreadAlerts,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              title: 'Insights',
              count: insightsCount,
              isSelected: activeTab == _AnalysisTab.insights,
              isDark: isDark,
              onTap: () => onTabChanged(_AnalysisTab.insights),
            ),
          ),
          Expanded(
            child: _tabButton(
              title: 'Cannibalization',
              count: cannibalCount,
              badgeColor: cannibalCount > 0 ? const Color(0xFFDC2626) : null,
              isSelected: activeTab == _AnalysisTab.cannibalization,
              isDark: isDark,
              onTap: () => onTabChanged(_AnalysisTab.cannibalization),
            ),
          ),
          Expanded(
            child: _tabButton(
              title: 'Ranking Alerts',
              count: alertsCount,
              badgeColor: hasUnreadAlerts ? AppColors.accent : null,
              isSelected: activeTab == _AnalysisTab.alerts,
              isDark: isDark,
              onTap: () => onTabChanged(_AnalysisTab.alerts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required int count,
    Color? badgeColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius - 2),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkCard : AppColors.surfacePrimary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius - 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ??
                        (isSelected ? AppColors.accent : const Color(0xFF64748B)))
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ??
                      (isSelected ? AppColors.accent : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Insights Tab ---

  Widget _buildInsightsTab(
    BuildContext context,
    bool isDark,
    List<KeywordInsight> insights,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterChips(context, isDark),
        const SizedBox(height: AppSpacing.sm),
        _buildCategorySelector(context, isDark),
        const SizedBox(height: AppSpacing.md),
        if (insights.isEmpty)
          _buildCleanState(isDark)
        else
          ...insights.map((insight) => _buildInsightCard(context, isDark, insight)),
      ],
    );
  }

  // --- Cannibalization Diagnostics Tab ---

  Widget _buildCannibalizationTab(
    BuildContext context,
    bool isDark,
    List<CannibalizationFinding> findings,
  ) {
    List<CannibalizationFinding> filtered = findings;
    if (cannibalConfidenceFilter != null) {
      filtered =
          filtered.where((f) => f.confidence == cannibalConfidenceFilter).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Explanatory Banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Keyword cannibalization occurs when multiple landing pages compete for impressions and traffic on the same search query. Consolidating authority or setting canonical tags clarifies ranking signals.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Confidence Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text('All (${findings.length})'),
                selected: cannibalConfidenceFilter == null,
                onSelected: (_) => onCannibalFilterChanged(null),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('High Confidence'),
                selected:
                    cannibalConfidenceFilter == CannibalizationConfidence.high,
                onSelected: (_) =>
                    onCannibalFilterChanged(CannibalizationConfidence.high),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Medium Confidence'),
                selected:
                    cannibalConfidenceFilter == CannibalizationConfidence.medium,
                onSelected: (_) =>
                    onCannibalFilterChanged(CannibalizationConfidence.medium),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Low Confidence'),
                selected:
                    cannibalConfidenceFilter == CannibalizationConfidence.low,
                onSelected: (_) =>
                    onCannibalFilterChanged(CannibalizationConfidence.low),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Findings List
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorderSubtle
                    : AppColors.borderSubtle,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 48,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Cannibalization Conflicts Found',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every tracked search query points to a distinct, unique landing page without overlapping competition.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...filtered.map((f) => _buildCannibalizationCard(context, isDark, f)),
      ],
    );
  }

  Widget _buildCannibalizationCard(
    BuildContext context,
    bool isDark,
    CannibalizationFinding finding,
  ) {
    Color badgeColor;
    switch (finding.confidence) {
      case CannibalizationConfidence.high:
        badgeColor = const Color(0xFFDC2626);
        break;
      case CannibalizationConfidence.medium:
        badgeColor = const Color(0xFFD97706);
        break;
      case CannibalizationConfidence.low:
        badgeColor = const Color(0xFF64748B);
        break;
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Keyword & Confidence Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finding.keywordText,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Engine: ${finding.searchEngine} • Range: ${finding.dateRange}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    finding.confidenceLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Competing URLs Table/List
            const Text(
              'Competing Landing Pages',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...finding.affectedUrls.map((urlMetric) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        urlMetric.url,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${urlMetric.impressions} imp'
                      '${urlMetric.clicks > 0 ? " • ${urlMetric.clicks} clk" : ""}'
                      '${urlMetric.averagePosition != null ? " • Avg #${urlMetric.averagePosition!.toStringAsFixed(1)}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),

            // Diagnostic Evidence
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Observed Evidence',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    finding.evidence,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'Recommendation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    finding.recommendation,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Ranking Alerts Tab ---

  Widget _buildAlertsTab(
    BuildContext context,
    bool isDark,
    List<RankingAlert> alerts,
    WidgetRef ref,
  ) {
    List<RankingAlert> filtered = alerts;
    if (alertSeverityFilter == 'unread') {
      filtered = filtered.where((a) => !a.isRead).toList();
    } else if (alertSeverityFilter != 'all') {
      filtered =
          filtered.where((a) => a.severity == alertSeverityFilter).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('All (${alerts.length})'),
                    selected: alertSeverityFilter == 'all',
                    onSelected: (_) => onAlertFilterChanged('all'),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: Text(
                      'Unread (${alerts.where((a) => !a.isRead).length})',
                    ),
                    selected: alertSeverityFilter == 'unread',
                    onSelected: (_) => onAlertFilterChanged('unread'),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Critical'),
                    selected: alertSeverityFilter == 'critical',
                    onSelected: (_) => onAlertFilterChanged('critical'),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Warning'),
                    selected: alertSeverityFilter == 'warning',
                    onSelected: (_) => onAlertFilterChanged('warning'),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) async {
                if (val == 'mark_all_read') {
                  await ref
                      .read(rankingAlertsFamilyProvider(website.id!).notifier)
                      .markAllAsRead();
                } else if (val == 'clear_all') {
                  await ref
                      .read(rankingAlertsFamilyProvider(website.id!).notifier)
                      .clearAll();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Text('Mark All as Read'),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear All Alerts'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorderSubtle
                    : AppColors.borderSubtle,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.notifications_none_outlined,
                  size: 48,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Ranking Alerts',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'All ranking movements and landing pages are within normal operating thresholds.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...filtered.map((a) => _buildAlertCard(context, isDark, a, ref)),
      ],
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    bool isDark,
    RankingAlert alert,
    WidgetRef ref,
  ) {
    Color severityColor;
    IconData alertIcon;

    switch (alert.severity) {
      case 'critical':
        severityColor = const Color(0xFFDC2626);
        break;
      case 'warning':
        severityColor = const Color(0xFFD97706);
        break;
      default:
        severityColor = AppColors.accent;
    }

    switch (alert.alertType) {
      case 'rank_gain':
        alertIcon = Icons.trending_up;
        break;
      case 'rank_drop':
        alertIcon = Icons.trending_down;
        break;
      case 'new_query':
        alertIcon = Icons.fiber_new;
        break;
      case 'lost_query':
        alertIcon = Icons.cancel_outlined;
        break;
      case 'url_change':
        alertIcon = Icons.swap_horiz;
        break;
      case 'cannibalization':
        alertIcon = Icons.warning_amber_rounded;
        break;
      default:
        alertIcon = Icons.notifications_outlined;
    }

    final dateStr = DateFormat('MMM d, h:mm a').format(alert.createdAt);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(alertIcon, color: severityColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight:
                                alert.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.searchEngine,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (val) async {
                if (val == 'toggle_read') {
                  await ref
                      .read(rankingAlertsFamilyProvider(website.id!).notifier)
                      .markAsRead(alert.id!);
                } else if (val == 'delete') {
                  await ref
                      .read(rankingAlertsFamilyProvider(website.id!).notifier)
                      .deleteAlert(alert.id!);
                }
              },
              itemBuilder: (_) => [
                if (!alert.isRead)
                  const PopupMenuItem(
                    value: 'toggle_read',
                    child: Text('Mark as Read'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Alert'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Shared / Existing UI Components ---

  Widget _buildWebsiteHeader(BuildContext context, bool isDark, WidgetRef ref) {
    return GlassContainer(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: website.id,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
          items: allWebsites.map((w) {
            return DropdownMenuItem<int>(
              value: w.id,
              child: Row(
                children: [
                  Icon(
                    w.isCompetitor ? Icons.compare_arrows : Icons.language,
                    size: 18,
                    color:
                        w.isCompetitor ? AppColors.rankTop3 : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${w.label} (${w.domain})',
                      style: AppTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newId) {
            if (newId != null && newId != website.id) {
              ref.read(selectedWebsiteIdProvider.notifier).select(newId);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark) {
    final engines = ['All', 'Google', 'Bing', 'Yandex'];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: engines.map((eng) {
                final isSelected = selectedEngine == eng;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(eng),
                    selected: isSelected,
                    selectedColor: AppColors.accent.withAlpha(isDark ? 50 : 30),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.accent
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary),
                    ),
                    backgroundColor: isDark
                        ? AppColors.darkCard
                        : AppColors.surfaceSecondary,
                    onSelected: (_) => onEngineChanged(eng),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(BuildContext context, bool isDark) {
    final categories = <InsightType?, String>{
      null: 'All Insights',
      InsightType.improving: 'Rank Gains',
      InsightType.declining: 'Rank Drops',
      InsightType.ctrOpportunity: 'CTR Opportunities',
      InsightType.newKeyword: 'New Queries',
      InsightType.lostKeyword: 'Lost Queries',
      InsightType.rankingUrlChange: 'URL Changes',
      InsightType.cannibalization: 'Cannibalization',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.entries.map((entry) {
          final isSelected = selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              selectedColor: AppColors.accent,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              ),
              backgroundColor:
                  isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
              onSelected: (_) => onCategoryChanged(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCleanState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Color(0xFF10B981),
            ),
            const SizedBox(height: 12),
            Text(
              'No Actionable Anomalies Found',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search metrics and ranking observations are steady for the active filters.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    bool isDark,
    KeywordInsight insight,
  ) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: insight.color.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(insight.icon, color: insight.color, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              insight.title,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              insight.searchEngine,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insight.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.data_exploration_outlined,
                          size: 13, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Data Basis (${insight.dateRange})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    insight.dataBasis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      const Text(
                        'Limitation & Guidance',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    insight.limitation,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
