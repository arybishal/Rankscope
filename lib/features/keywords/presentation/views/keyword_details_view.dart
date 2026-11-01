import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../../shared/widgets/cards/ranking_badge.dart';
import '../../../../shared/widgets/charts/trend_line_chart.dart';
import '../../../../shared/widgets/dialogs/add_keyword_dialog.dart';
import '../../../../shared/widgets/dialogs/log_rank_dialog.dart';
import '../../../../shared/widgets/dialogs/move_keyword_group_dialog.dart';
import '../../../websites/domain/entities/website.dart';
import '../controllers/keywords_controller.dart';

class KeywordDetailsView extends ConsumerStatefulWidget {
  final Keyword initialKeyword;
  final Website website;

  const KeywordDetailsView({
    super.key,
    required this.initialKeyword,
    required this.website,
  });

  @override
  ConsumerState<KeywordDetailsView> createState() => _KeywordDetailsViewState();
}

enum _TimeRange { sevenDays, thirtyDays, ninetyDays, all }

Color _parseHex(String? hexString, {Color fallback = const Color(0xFF2563EB)}) {
  if (hexString == null || hexString.isEmpty) return fallback;
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (_) {
    return fallback;
  }
}

class _KeywordDetailsViewState extends ConsumerState<KeywordDetailsView> {
  _TimeRange _timeRange = _TimeRange.thirtyDays;
  String _activeEngineTab = 'All'; // 'All', 'Google', 'Bing', 'Yandex', 'Manual'

  void _openEditDialog(BuildContext context, Keyword kw) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AddKeywordDialog(websiteId: widget.website.id!, initialKeyword: kw),
    );
  }

  void _openLogRankDialog(BuildContext context, Keyword kw) {
    showDialog(
      context: context,
      builder: (ctx) =>
          LogRankDialog(keyword: kw, websiteId: widget.website.id!),
    );
  }

  void _confirmDelete(BuildContext context, Keyword kw) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
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
                  .read(keywordsFamilyProvider(widgetWebsiteId).notifier)
                  .deleteKeyword(kw.id!);
              if (context.mounted) {
                Navigator.of(context).pop();
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

  int get widgetWebsiteId => widget.website.id!;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordsAsync = ref.watch(keywordsFamilyProvider(widgetWebsiteId));
    final observationsAsync = ref.watch(
      keywordObservationsFamilyProvider(widget.initialKeyword.id!),
    );

    // Resolve latest live keyword from family provider
    final Keyword keyword = keywordsAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (k) => k.id == widget.initialKeyword.id,
        orElse: () => widget.initialKeyword,
      ),
      orElse: () => widget.initialKeyword,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: Text(
          keyword.keywordText,
          style: AppTextStyles.titleLarge.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            tooltip: 'Move to Group',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => MoveKeywordGroupDialog(
                  websiteId: widgetWebsiteId,
                  keywordIds: [keyword.id!],
                  keywordSummaryText: keyword.keywordText,
                  currentGroupId: keyword.groupId,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Keyword',
            onPressed: () => _openEditDialog(context, keyword),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.rankDrop),
            tooltip: 'Delete Keyword',
            onPressed: () => _confirmDelete(context, keyword),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  keyword.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 18,
                ),
                label: Text(keyword.isActive ? 'Pause' : 'Resume'),
                onPressed: () {
                  ref
                      .read(keywordsFamilyProvider(widgetWebsiteId).notifier)
                      .toggleActive(keyword.id!, !keyword.isActive);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_chart, size: 18),
                label: const Text('Log SERP Rank'),
                onPressed: () => _openLogRankDialog(context, keyword),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Keyword Metadata & Status Chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                label: keyword.isActive ? 'Active' : 'Paused',
                color: keyword.isActive ? AppColors.rankGain : AppColors.textTertiary,
              ),
              if (keyword.isNew)
                const _StatusPill(label: 'NEW', color: AppColors.accent),
              if (keyword.isLost)
                const _StatusPill(label: 'LOST', color: AppColors.rankDrop),
              if (keyword.isRecovered)
                const _StatusPill(label: 'RECOVERED', color: Color(0xFF16A34A)),
              if (keyword.groupId != null)
                ref.watch(keywordGroupsFamilyProvider(widgetWebsiteId)).maybeWhen(
                  data: (groups) {
                    final match = groups.where((g) => g.id == keyword.groupId);
                    if (match.isEmpty) return const SizedBox.shrink();
                    final g = match.first;
                    final color = _parseHex(g.colorHex);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              Text(
                '• ${keyword.targetCountry} • ${keyword.device}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Separate Engine Tabs (All, Google, Bing, Yandex, Manual SERP)
          _buildEngineTabBar(isDark),
          const SizedBox(height: AppSpacing.md),

          // 3. Search Performance Overview Card for Selected Engine
          _buildPerformanceCard(isDark, keyword),
          const SizedBox(height: AppSpacing.md),

          // 4. Educational Disambiguation Card: Avg Position vs Exact Rank
          _buildDisambiguationCard(isDark),
          const SizedBox(height: AppSpacing.md),

          // 5. Position Trend Chart Over Selected Timeframe
          observationsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (observations) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrendChartSection(isDark, observations),
                  const SizedBox(height: AppSpacing.md),
                  _buildUrlChangeHistorySection(isDark, keyword, observations),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // 6. Cannibalization Alert Banner (if detected)
          if (keyword.hasCannibalization) ...[
            _buildCannibalizationBanner(isDark, keyword),
            const SizedBox(height: AppSpacing.md),
          ],

          // 7. Target URL & Landing Pages Matching Section
          _buildLandingPagesSection(context, isDark, keyword),
          const SizedBox(height: AppSpacing.lg),

          // 8. Observation History Timeline & Filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Observation History',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              SegmentedButton<_TimeRange>(
                segments: const [
                  ButtonSegment(value: _TimeRange.sevenDays, label: Text('7D')),
                  ButtonSegment(value: _TimeRange.thirtyDays, label: Text('30D')),
                  ButtonSegment(value: _TimeRange.ninetyDays, label: Text('90D')),
                  ButtonSegment(value: _TimeRange.all, label: Text('All')),
                ],
                selected: {_timeRange},
                onSelectionChanged: (set) => setState(() => _timeRange = set.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          observationsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (observations) {
              final filtered = _filterObservations(observations, _timeRange, _activeEngineTab);

              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No rank observations logged in this timeframe.\nTap "Sync Performance" on Overview or "Log SERP Rank" to record observations.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
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
                separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final obs = filtered[index];
                  final formattedDate =
                      DateFormat('MMM dd, yyyy • HH:mm').format(obs.recordedAt);

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
                        RankingBadge(
                          position: obs.position == 0 ? 0 : obs.position,
                          delta: 0,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    obs.searchEngine,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      obs.source.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                                      ),
                                    ),
                                  ),
                                  if (obs.averagePosition != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'Avg: ${obs.averagePosition!.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                  if (obs.isUrlChange) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'URL Changed',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (obs.clicks > 0 || obs.impressions > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Clicks: ${obs.clicks} • Impressions: ${obs.impressions}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              if (obs.rankingUrl != null && obs.rankingUrl!.isNotEmpty)
                                Text(
                                  obs.rankingUrl!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEngineTabBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildEngineTabPill(isDark, 'All Sources', 'All', Icons.apps),
          const SizedBox(width: 6),
          _buildEngineTabPill(isDark, 'Google (GSC)', 'Google', Icons.search),
          const SizedBox(width: 6),
          _buildEngineTabPill(isDark, 'Bing Webmaster', 'Bing', Icons.travel_explore),
          const SizedBox(width: 6),
          _buildEngineTabPill(isDark, 'Yandex', 'Yandex', Icons.travel_explore_outlined),
          const SizedBox(width: 6),
          _buildEngineTabPill(isDark, 'Manual SERP', 'Manual', Icons.rule),
        ],
      ),
    );
  }

  Widget _buildEngineTabPill(bool isDark, String label, String value, IconData icon) {
    final isSelected = _activeEngineTab == value;
    final activeBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
    final inactiveBg = isDark ? AppColors.darkCard : AppColors.surfaceSecondary;
    final activeBorder = isDark ? const Color(0xFF3B82F6) : AppColors.accent;
    final inactiveBorder = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final activeTextColor = isDark ? Colors.white : AppColors.accent;

    return InkWell(
      onTap: () => setState(() => _activeEngineTab = value),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeTextColor : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeTextColor : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisambiguationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: isDark ? AppColors.darkAccent : AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Average Position vs Exact SERP Rank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Webmaster tools (Google Search Console, Bing, Yandex) report Average Position calculated across thousands of real search impressions across varied devices and regions. Discrete SERP Audit reflects a single point-in-time check from your device.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartSection(bool isDark, List<RankObservation> observations) {
    // Filter observations for chart series
    final filtered = _filterObservations(observations, _timeRange, _activeEngineTab);

    // Group into series by engine
    final Map<String, List<ChartDataPoint>> seriesData = {};
    for (final obs in filtered) {
      if (obs.position <= 0) continue;
      final eng = obs.searchEngine;
      final val = obs.averagePosition ?? obs.position.toDouble();
      seriesData.putIfAbsent(eng, () => []).add(
        ChartDataPoint(date: obs.recordedAt, value: val),
      );
    }

    final colors = {
      'Google': const Color(0xFF2563EB),
      'Bing': const Color(0xFF0D9488),
      'Yandex': const Color(0xFFEA580C),
      'Manual': const Color(0xFF7C3AED),
    };

    final List<ChartSeries> chartSeries = [];
    seriesData.forEach((eng, pts) {
      pts.sort((a, b) => a.date.compareTo(b.date));
      if (pts.length >= 2) {
        chartSeries.add(
          ChartSeries(
            name: eng,
            points: pts,
            color: colors[eng] ?? const Color(0xFF64748B),
          ),
        );
      }
    });

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Position Movement Trend',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              Text(
                _timeRangeLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TrendLineChart(
            series: chartSeries,
            height: 170,
            invertYAxis: true,
            yAxisSuffix: ' pos',
            emptyMessage:
                'Insufficient data points in this timeframe to render trend line.\nObservations will appear after running Search Performance Sync.',
          ),
        ],
      ),
    );
  }

  Widget _buildUrlChangeHistorySection(
    bool isDark,
    Keyword keyword,
    List<RankObservation> observations,
  ) {
    // Extract unique ranking URLs over time
    final urlChanges = observations
        .where((o) => o.rankingUrl != null && o.rankingUrl!.isNotEmpty)
        .toList();

    final Set<String> distinctUrls = {};
    final List<RankObservation> changes = [];
    for (final obs in urlChanges) {
      if (!distinctUrls.contains(obs.rankingUrl)) {
        distinctUrls.add(obs.rankingUrl!);
        changes.add(obs);
      }
    }

    if (changes.length < 2) return const SizedBox.shrink();

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
          Row(
            children: [
              const Icon(Icons.history, size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                'Observed URL Change History (${distinctUrls.length} Pages)',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Search engines observed multiple distinct URLs receiving impressions for this query.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          ...changes.map((obs) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obs.rankingUrl!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${obs.searchEngine} • First observed ${DateFormat('MMM d, yyyy').format(obs.recordedAt)} • Position #${obs.position}',
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
      ),
    );
  }

  Widget _buildCannibalizationBanner(bool isDark, Keyword keyword) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.rankDrop,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'Potential Cannibalization Alert',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.rankDrop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            keyword.cannibalizationStatus == 'url_switching'
                ? 'Frequent URL switching detected: search engines are oscillating between multiple URLs for this query.'
                : 'Multiple distinct URLs were observed ranking for this query across observation checks.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(bool isDark, Keyword kw) {
    final showGoogle = _activeEngineTab == 'All' || _activeEngineTab == 'Google';
    final showBing = _activeEngineTab == 'All' || _activeEngineTab == 'Bing';
    final showYandex = _activeEngineTab == 'All' || _activeEngineTab == 'Yandex';
    final showManual = _activeEngineTab == 'All' || _activeEngineTab == 'Manual';

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
            'Search Engine Average Performance',
            style: AppTextStyles.titleMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Google Performance Row
          if (showGoogle) ...[
            _buildEngineDetailsRow(
              isDark: isDark,
              engineName: 'Google Search Console Average Position',
              icon: Icons.search,
              brandColor: const Color(0xFF1D4ED8),
              avgPos: kw.googleAveragePosition,
              clicks: kw.googleClicks,
              impressions: kw.googleImpressions,
              rankingUrl: kw.googleRankingUrl,
              syncedAt: kw.googleSyncedAt,
            ),
          ],

          if (showGoogle && showBing) const Divider(height: 16),

          // Bing Performance Row
          if (showBing) ...[
            _buildEngineDetailsRow(
              isDark: isDark,
              engineName: 'Bing Webmaster',
              icon: Icons.travel_explore,
              brandColor: const Color(0xFF0F766E),
              avgPos: kw.bingAveragePosition,
              clicks: kw.bingClicks,
              impressions: kw.bingImpressions,
              rankingUrl: kw.bingRankingUrl,
              syncedAt: kw.bingSyncedAt,
            ),
          ],

          if ((showGoogle || showBing) && showYandex) const Divider(height: 16),

          // Yandex Performance Row
          if (showYandex) ...[
            _buildEngineDetailsRow(
              isDark: isDark,
              engineName: 'Yandex Webmaster',
              icon: Icons.travel_explore_outlined,
              brandColor: const Color(0xFFEA580C),
              avgPos: kw.yandexAveragePosition,
              clicks: kw.yandexClicks,
              impressions: kw.yandexImpressions,
              rankingUrl: kw.yandexRankingUrl,
              syncedAt: kw.yandexSyncedAt,
            ),
          ],

          if (showManual) ...[
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rule, size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual Observation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Google #${kw.googlePosition ?? "—"} • Bing #${kw.bingPosition ?? "—"} • Yandex #${kw.yandexPosition ?? "—"}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEngineDetailsRow({
    required bool isDark,
    required String engineName,
    required IconData icon,
    required Color brandColor,
    required double? avgPos,
    required int clicks,
    required int impressions,
    required String? rankingUrl,
    required DateTime? syncedAt,
  }) {
    final hasData = avgPos != null && avgPos > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: brandColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                engineName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: brandColor,
                ),
              ),
              const SizedBox(height: 2),
              if (hasData) ...[
                Text(
                  'Average Position: ${avgPos.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Clicks: $clicks • Impressions: $impressions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                if (rankingUrl != null && rankingUrl.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    rankingUrl,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (syncedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last synced: ${DateFormatter.relativeTime(syncedAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  engineName.contains('Google')
                      ? 'No Google data available'
                      : 'No search performance data recorded yet.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandingPagesSection(BuildContext context, bool isDark, Keyword keyword) {
    final bestUrl = keyword.googleRankingUrl ??
        keyword.bingRankingUrl ??
        keyword.yandexRankingUrl ??
        keyword.rankingUrl;
    final isMatch = UrlValidator.urlsMatch(keyword.targetUrl, bestUrl);

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
          Row(
            children: [
              Icon(Icons.link, size: 18, color: isDark ? AppColors.darkAccent : AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Landing Pages & Target Matching',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (bestUrl != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy URL',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bestUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ranking URL copied to clipboard.'),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Target Landing Page
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎯 Target: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  keyword.targetUrl != null && keyword.targetUrl!.isNotEmpty
                      ? keyword.targetUrl!
                      : 'None set (optional)',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: keyword.targetUrl != null ? 'monospace' : null,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Observed Ranking Page
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌐 Observed: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  bestUrl ?? 'No landing page captured yet',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: bestUrl != null ? 'monospace' : null,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Target Match Badge
          if (keyword.targetUrl != null && bestUrl != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMatch
                    ? (isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4))
                    : (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB)),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isMatch
                      ? (isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0))
                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMatch ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 13,
                    color: isMatch ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMatch
                        ? 'Search Visibility Matches Expected Target Page'
                        : 'Different Page Ranking than Target URL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMatch ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<RankObservation> _filterObservations(
    List<RankObservation> observations,
    _TimeRange range,
    String engine,
  ) {
    final now = DateTime.now();
    DateTime cutoff;

    switch (range) {
      case _TimeRange.sevenDays:
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case _TimeRange.thirtyDays:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case _TimeRange.ninetyDays:
        cutoff = now.subtract(const Duration(days: 90));
        break;
      case _TimeRange.all:
        cutoff = DateTime(1970);
        break;
    }

    return observations.where((o) {
      if (o.recordedAt.isBefore(cutoff)) return false;
      if (engine != 'All') {
        if (engine == 'Manual') {
          return o.source == 'manual';
        }
        return o.searchEngine.toLowerCase() == engine.toLowerCase();
      }
      return true;
    }).toList();
  }

  String get _timeRangeLabel {
    switch (_timeRange) {
      case _TimeRange.sevenDays:
        return 'Last 7 Days';
      case _TimeRange.thirtyDays:
        return 'Last 30 Days';
      case _TimeRange.ninetyDays:
        return 'Last 90 Days';
      case _TimeRange.all:
        return 'All Time';
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
