import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
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
                label: const Text('Log Rank'),
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

          // Search Engine Positions Comparison Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
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
                  height: 60,
                  color: AppColors.borderSubtle,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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

          // Ranking URL Section
          Container(
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
                      'Detected Ranking URL',
                      style: AppTextStyles.labelLarge,
                    ),
                    const Spacer(),
                    if (keyword.rankingUrl != null)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy URL',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: keyword.rankingUrl!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ranking URL copied to clipboard.'),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  keyword.rankingUrl ?? 'No ranking URL detected yet',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: keyword.rankingUrl != null
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (keyword.targetUrl != null &&
                    keyword.targetUrl!.isNotEmpty) ...[
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Target Landing Page: ',
                        style: AppTextStyles.labelMedium,
                      ),
                      Expanded(
                        child: Text(
                          keyword.targetUrl!,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontFamily: 'monospace',
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
          const SizedBox(height: AppSpacing.lg),

          // Observation History & Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rank Observation History',
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
                      'No rank observations logged in this timeframe.\nTap "Log Rank" below to record the first verified SERP observation.',
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
                                      color: AppColors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      obs.source,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
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
                              const SizedBox(height: 2),
                              if (obs.rankingUrl != null &&
                                  obs.rankingUrl!.isNotEmpty)
                                Text(
                                  obs.rankingUrl!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (obs.previousRankingUrl != null &&
                                  obs.isUrlChange)
                                Text(
                                  'Previous: ${obs.previousRankingUrl}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontFamily: 'monospace',
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textTertiary,
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
