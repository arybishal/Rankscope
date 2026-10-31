import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/feedback/empty_state_view.dart';
import '../../../../shared/widgets/surfaces/glass_container.dart';
import '../../../keywords/data/services/keyword_analysis_service.dart';
import '../../../keywords/presentation/controllers/keywords_controller.dart';
import '../../../keywords/presentation/views/keyword_details_view.dart';
import '../../../websites/presentation/controllers/websites_controller.dart';

class AnalysisView extends ConsumerStatefulWidget {
  const AnalysisView({super.key});

  @override
  ConsumerState<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends ConsumerState<AnalysisView> {
  String _selectedEngine = 'All'; // All, Google, Bing, Yandex
  InsightType? _selectedCategory; // null = all
  String _timeRange = 'Last 28 Days';

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
            selectedEngine: _selectedEngine,
            selectedCategory: _selectedCategory,
            timeRange: _timeRange,
            onEngineChanged: (e) => setState(() => _selectedEngine = e),
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
            onTimeRangeChanged: (t) => setState(() => _timeRange = t),
          );
        },
      ),
    );
  }
}

class _AnalysisContent extends ConsumerWidget {
  final Website website;
  final List<Website> allWebsites;
  final String selectedEngine;
  final InsightType? selectedCategory;
  final String timeRange;
  final ValueChanged<String> onEngineChanged;
  final ValueChanged<InsightType?> onCategoryChanged;
  final ValueChanged<String> onTimeRangeChanged;

  const _AnalysisContent({
    required this.website,
    required this.allWebsites,
    required this.selectedEngine,
    required this.selectedCategory,
    required this.timeRange,
    required this.onEngineChanged,
    required this.onCategoryChanged,
    required this.onTimeRangeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordsState = ref.watch(keywordsFamilyProvider(website.id!));
    final cannibalizationState = ref.watch(cannibalizationAlertsFamilyProvider(website.id!));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref.read(keywordsFamilyProvider(website.id!).notifier).loadKeywords();
        ref.invalidate(cannibalizationAlertsFamilyProvider(website.id!));
      },
      child: keywordsState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading analysis: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (keywords) {
          if (keywords.isEmpty) {
            return EmptyStateView(
              icon: Icons.insights_outlined,
              title: 'No Keywords Tracked',
              description: 'Add keywords or sync performance data to generate SEO intelligence insights.',
              actionLabel: 'Go to Overview',
              onAction: () => context.go('/dashboard'),
            );
          }

          // Build keyword observations map from available keyword history
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
                  recordedAt: DateTime.now().subtract(const Duration(days: 14)),
                  source: 'historical',
                ),
              );
              list.add(
                RankObservation(
                  keywordId: kw.id!,
                  websiteId: website.id!,
                  searchEngine: kw.searchEngine,
                  position: kw.latestPosition!,
                  rankingUrl: kw.googleRankingUrl ?? kw.bingRankingUrl ?? kw.yandexRankingUrl ?? kw.targetUrl,
                  recordedAt: DateTime.now(),
                  source: 'latest',
                ),
              );
            }
            obsMap[kw.id!] = list;
          }

          // Generate insights via KeywordAnalysisService
          const service = KeywordAnalysisService();
          List<KeywordInsight> insights = service.generateInsights(
            keywords: keywords,
            observationsByKeywordId: obsMap,
            timeFrameLabel: timeRange,
          );

          // Filter by search engine
          if (selectedEngine != 'All') {
            insights = insights.where((ins) {
              final eng = ins.searchEngine.toLowerCase();
              return eng.contains(selectedEngine.toLowerCase());
            }).toList();
          }

          // Filter by category
          if (selectedCategory != null) {
            insights = insights.where((ins) => ins.type == selectedCategory).toList();
          }

          // Count totals
          final int cannibalizationCount = cannibalizationState.value?.length ?? 0;
          final int oppCount = insights.where((i) => i.type == InsightType.ctrOpportunity).length;
          final int improvingCount = insights.where((i) => i.type == InsightType.improving).length;
          final int decliningCount = insights.where((i) => i.type == InsightType.declining).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 1. Website Switcher Header
              _buildWebsiteHeader(context, isDark, ref),
              const SizedBox(height: AppSpacing.md),

              // 2. Metrics Summary Strip
              _buildSummaryCards(
                context,
                isDark,
                totalInsights: insights.length,
                cannibalizationCount: cannibalizationCount,
                oppCount: oppCount,
                improvingCount: improvingCount,
                decliningCount: decliningCount,
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Engine & Timeframe Filters
              _buildFilterChips(context, isDark),
              const SizedBox(height: AppSpacing.md),

              // 4. Category Selector Chips
              _buildCategorySelector(context, isDark),
              const SizedBox(height: AppSpacing.md),

              // 5. Insights Cards List
              if (insights.isEmpty)
                _buildCleanState(isDark)
              else
                ...insights.map((insight) => _buildInsightCard(context, isDark, insight)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebsiteHeader(BuildContext context, bool isDark, WidgetRef ref) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
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
                    color: w.isCompetitor ? AppColors.rankTop3 : AppColors.accent,
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

  Widget _buildSummaryCards(
    BuildContext context,
    bool isDark, {
    required int totalInsights,
    required int cannibalizationCount,
    required int oppCount,
    required int improvingCount,
    required int decliningCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _summaryBox(
            isDark,
            title: 'Insights',
            value: '$totalInsights',
            icon: Icons.insights,
            color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryBox(
            isDark,
            title: 'CTR Opps',
            value: '$oppCount',
            icon: Icons.trending_up,
            color: AppColors.rankGain,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryBox(
            isDark,
            title: 'Declining',
            value: '$decliningCount',
            icon: Icons.trending_down,
            color: AppColors.rankDrop,
          ),
        ),
      ],
    );
  }

  Widget _summaryBox(
    bool isDark, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark) {
    final engines = ['All', 'Google', 'Bing', 'Yandex'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: engines.map((eng) {
          final isSelected = selectedEngine == eng;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(eng),
              selected: isSelected,
              showCheckmark: false,
              backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
              selectedColor: isDark ? const Color(0xFF1E3A8A) : AppColors.accentLight,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (isDark ? const Color(0xFF93C5FD) : AppColors.accent)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
              side: BorderSide(
                color: isSelected
                    ? (isDark ? const Color(0xFF60A5FA) : AppColors.accent)
                    : (isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle),
              ),
              onSelected: (_) => onEngineChanged(eng),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context, bool isDark) {
    final categories = <InsightType?, String>{
      null: 'All Insights',
      InsightType.cannibalization: 'Cannibalization',
      InsightType.ctrOpportunity: 'CTR Opportunities',
      InsightType.improving: 'Improving',
      InsightType.declining: 'Declining',
      InsightType.rankingUrlChange: 'URL Changes',
      InsightType.newKeyword: 'New Queries',
      InsightType.lostKeyword: 'Lost Queries',
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
              showCheckmark: false,
              backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
              selectedColor: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceTertiary,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    : (isDark ? AppColors.darkTextTertiary : AppColors.textSecondary),
              ),
              side: BorderSide(
                color: isSelected
                    ? (isDark ? AppColors.darkBorderFocus : AppColors.borderFocus)
                    : (isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle),
              ),
              onSelected: (_) => onCategoryChanged(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCleanState(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 40, color: AppColors.rankGain),
          const SizedBox(height: 12),
          Text(
            'No Actionable Anomalies Detected',
            style: AppTextStyles.titleMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your monitored keywords show stable rankings within the $timeRange timeframe without severe cannibalization or abrupt drops.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, bool isDark, KeywordInsight insight) {
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
              builder: (_) => KeywordDetailsView(
                initialKeyword: insight.keyword,
                website: website,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title + Severity Tag + Search Engine Tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: insight.color.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(insight.icon, size: 16, color: insight.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      insight.searchEngine,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: AppSpacing.sm),

              // Transparent Data Basis
              _infoRow(
                isDark,
                label: 'Data Basis:',
                text: insight.dataBasis,
                icon: Icons.history_edu_outlined,
              ),
              const SizedBox(height: 4),

              // Timeframe & Limitation
              _infoRow(
                isDark,
                label: 'Timeframe:',
                text: insight.dateRange,
                icon: Icons.date_range_outlined,
              ),
              const SizedBox(height: 4),

              _infoRow(
                isDark,
                label: 'Limitation:',
                text: insight.limitation,
                icon: Icons.info_outline,
                isSubtle: true,
              ),

              const SizedBox(height: 8),
              // Footer Action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Inspect Keyword',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    bool isDark, {
    required String label,
    required String text,
    required IconData icon,
    bool isSubtle = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontStyle: isSubtle ? FontStyle.italic : FontStyle.normal,
              color: isSubtle
                  ? (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
