import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/utils/date_formatter.dart';
import 'package:rankscope/core/utils/url_validator.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';
import 'package:rankscope/shared/widgets/cards/ranking_badge.dart';
import 'package:rankscope/shared/widgets/dialogs/add_keyword_dialog.dart';
import 'package:rankscope/shared/widgets/dialogs/log_rank_dialog.dart';

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

class _KeywordDetailsViewState extends ConsumerState<KeywordDetailsView> {
  _TimeRange _timeRange = _TimeRange.thirtyDays;

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
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: Text(
          keyword.keywordText,
          style: AppTextStyles.titleLarge,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
          color: AppColors.surfacePrimary,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
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
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.surfacePrimary,
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
          // Keyword Metadata & Status Row
          Row(
            children: [
              _StatusPill(
                label: keyword.isActive ? 'Active' : 'Paused',
                color: keyword.isActive
                    ? AppColors.rankGain
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              if (keyword.isNew) ...[
                const _StatusPill(label: 'NEW', color: AppColors.accent),
                const SizedBox(width: 6),
              ],
              if (keyword.isLost) ...[
                const _StatusPill(label: 'LOST', color: AppColors.rankDrop),
                const SizedBox(width: 6),
              ],
              if (keyword.isRecovered) ...[
                const _StatusPill(label: 'RECOVERED', color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Text(
                '${keyword.targetCountry} • ${keyword.device}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Search Console & Bing Search Performance Card
          _buildPerformanceCard(keyword),
          const SizedBox(height: AppSpacing.md),

          // SERP Audit Manual Positions Comparison Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rule, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Manual SERP Audit Positions',
                      style: AppTextStyles.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _EnginePositionTile(
                        engineName: 'Google',
                        position: keyword.googlePosition,
                        delta: keyword.googleDelta,
                        previousPos: keyword.googlePreviousPosition,
                        icon: Icons.search,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.borderSubtle,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    Expanded(
                      child: _EnginePositionTile(
                        engineName: 'Bing',
                        position: keyword.bingPosition,
                        delta: keyword.bingDelta,
                        previousPos: keyword.bingPreviousPosition,
                        icon: Icons.travel_explore,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Cannibalization Alert Banner (if detected)
          if (keyword.hasCannibalization) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: const Color(0xFFFECACA)),
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
                      color: const Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Target URL & Landing Pages Section
          _buildLandingPagesSection(context, keyword),
          const SizedBox(height: AppSpacing.lg),

          // Observation History & Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Observation History',
                style: AppTextStyles.titleMedium,
              ),
              SegmentedButton<_TimeRange>(
                segments: const [
                  ButtonSegment(value: _TimeRange.sevenDays, label: Text('7D')),
                  ButtonSegment(
                    value: _TimeRange.thirtyDays,
                    label: Text('30D'),
                  ),
                  ButtonSegment(
                    value: _TimeRange.ninetyDays,
                    label: Text('90D'),
                  ),
                  ButtonSegment(value: _TimeRange.all, label: Text('All')),
                ],
                selected: {_timeRange},
                onSelectionChanged: (set) =>
                    setState(() => _timeRange = set.first),
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
              final filtered = _filterObservations(observations, _timeRange);

              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Center(
                    child: Text(
                      'No rank observations logged in this timeframe.\nTap "Sync Search Performance" on Overview or "Log SERP Rank" to record observations.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, index) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final obs = filtered[index];
                  final formattedDate = DateFormat('MMM dd, yyyy • HH:mm')
                      .format(obs.recordedAt);

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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: obs.source == 'gsc'
                                          ? const Color(0xFFEFF6FF)
                                          : (obs.source == 'bing_api'
                                                ? const Color(0xFFF0FDF4)
                                                : AppColors.surfaceSecondary),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      obs.source.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: obs.source == 'gsc'
                                            ? AppColors.accent
                                            : (obs.source == 'bing_api'
                                                  ? const Color(0xFF16A34A)
                                                  : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                  if (obs.averagePosition != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'Avg: ${obs.averagePosition!.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                  if (obs.isUrlChange) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'URL Changed',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF92400E),
                                        ),
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
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              if (obs.rankingUrl != null &&
                                  obs.rankingUrl!.isNotEmpty)
                                Text(
                                  obs.rankingUrl!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
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

  Widget _buildPerformanceCard(Keyword kw) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Engine Average Performance',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 8),

          // Google Performance Row
          _buildEngineDetailsRow(
            engineName: 'Google Search Console',
            icon: Icons.search,
            brandColor: const Color(0xFF1D4ED8),
            avgPos: kw.googleAveragePosition,
            clicks: kw.googleClicks,
            impressions: kw.googleImpressions,
            rankingUrl: kw.googleRankingUrl,
            syncedAt: kw.googleSyncedAt,
          ),
          const Divider(height: 16),

          // Bing Performance Row
          _buildEngineDetailsRow(
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
      ),
    );
  }

  Widget _buildEngineDetailsRow({
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Clicks: $clicks • Impressions: $impressions',
                  style: AppTextStyles.bodySmall,
                ),
                if (rankingUrl != null && rankingUrl.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    rankingUrl,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (syncedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last synced: ${DateFormatter.relativeTime(syncedAt)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ] else ...[
                const Text(
                  'No search performance data recorded yet.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandingPagesSection(BuildContext context, Keyword keyword) {
    final bestUrl =
        keyword.googleRankingUrl ??
        keyword.bingRankingUrl ??
        keyword.rankingUrl;
    final isMatch = UrlValidator.urlsMatch(keyword.targetUrl, bestUrl);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text(
                'Landing Pages & Target Matching',
                style: AppTextStyles.labelLarge,
              ),
              const Spacer(),
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
              const Text(
                'Target URL: ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Text(
                  keyword.targetUrl ?? 'Not specified',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: keyword.targetUrl != null
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Detected Ranking URL
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Observed URL: ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Text(
                  bestUrl ?? 'No landing page detected in search analytics yet',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: bestUrl != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          if (keyword.targetUrl != null &&
              keyword.targetUrl!.isNotEmpty &&
              bestUrl != null &&
              bestUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMatch
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isMatch
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isMatch ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 14,
                    color: isMatch
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isMatch ? 'Observed ranking page matches target URL' : 'Different page ranking: search visibility is landing on a different page than intended',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMatch
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFB45309),
                      ),
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
    List<RankObservation> list,
    _TimeRange range,
  ) {
    if (range == _TimeRange.all) return list;
    final now = DateTime.now();
    final int days;
    switch (range) {
      case _TimeRange.sevenDays:
        days = 7;
        break;
      case _TimeRange.thirtyDays:
        days = 30;
        break;
      case _TimeRange.ninetyDays:
        days = 90;
        break;
      case _TimeRange.all:
        return list;
    }
    final cutoff = now.subtract(Duration(days: days));
    return list.where((o) => o.recordedAt.isAfter(cutoff)).toList();
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _EnginePositionTile extends StatelessWidget {
  final String engineName;
  final int? position;
  final int delta;
  final int? previousPos;
  final IconData icon;

  const _EnginePositionTile({
    required this.engineName,
    required this.position,
    required this.delta,
    required this.previousPos,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    String posText = '—';
    if (position != null) {
      posText = position == 0 ? 'Not Ranking (0)' : '#$position';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(engineName, style: AppTextStyles.labelMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          posText,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        if (delta != 0)
          Row(
            children: [
              Icon(
                delta > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 16,
                color: delta > 0 ? AppColors.rankGain : AppColors.rankDrop,
              ),
              Text(
                '${delta > 0 ? "+$delta" : delta} (was ${previousPos ?? "—"})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: delta > 0 ? AppColors.rankGain : AppColors.rankDrop,
                ),
              ),
            ],
          )
        else
          Text(
            previousPos != null
                ? 'Unchanged (was #$previousPos)'
                : 'No movement record',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
      ],
    );
  }
}
