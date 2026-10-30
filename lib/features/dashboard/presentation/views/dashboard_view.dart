import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/reporting/data/generators/csv_report_generator.dart';
import 'package:rankscope/features/reporting/data/generators/pdf_report_generator.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/cards/rank_metric_card.dart';
import 'package:rankscope/shared/widgets/cards/ranking_badge.dart';
import 'package:rankscope/shared/widgets/dialogs/add_website_dialog.dart';
import 'package:rankscope/shared/widgets/dialogs/log_rank_dialog.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';
import 'package:share_plus/share_plus.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);

    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('RankScope', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.language_outlined,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Manage Websites',
            onPressed: () => context.push('/websites'),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.textPrimary,
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
        error: (err, _) =>
            Center(child: Text('Error: $err', style: AppTextStyles.bodyMedium)),
        data: (websites) {
          final activeWebsite = websites.findActive(selectedSiteId);
          if (activeWebsite == null) {
            return EmptyStateView(
              icon: Icons.language,
              title: 'No Websites Tracked',
              description: 'Start by registering your primary website domain or a competitor to monitor.',
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

class _DashboardContent extends ConsumerWidget {
  final Website website;
  final List<Website> allWebsites;

  const _DashboardContent({required this.website, required this.allWebsites});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywordsState = ref.watch(keywordsFamilyProvider(website.id!));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref
            .read(keywordsFamilyProvider(website.id!).notifier)
            .loadKeywords();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Website Selector & Actions Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: website.id,
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
                      onChanged: (id) {
                        if (id != null) {
                          ref
                              .read(selectedWebsiteIdProvider.notifier)
                              .select(id);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Edit Website',
                onPressed: () => _openEditWebsiteDialog(context, website),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.rankDrop,
                ),
                tooltip: 'Delete Website',
                onPressed: () => _confirmDeleteWebsite(context, ref, website),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // KPI Grid
          keywordsState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => Text('Error loading keywords: $e'),
            data: (keywords) {
              final total = keywords.length;
              final top3 = keywords
                  .where((k) => (k.latestPosition ?? 101) <= 3)
                  .length;
              final top10 = keywords
                  .where((k) => (k.latestPosition ?? 101) <= 10)
                  .length;
              final ranked = keywords
                  .where((k) => k.latestPosition != null)
                  .toList();
              double avg = 0.0;
              if (ranked.isNotEmpty) {
                avg =
                    ranked.fold<int>(0, (sum, k) => sum + k.latestPosition!) /
                    ranked.length;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RankMetricCard(
                          title: 'Tracked',
                          value: '$total',
                          subtitle: 'Keywords',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: RankMetricCard(
                          title: 'Top 3',
                          value: '$top3',
                          subtitle: 'Positions',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: RankMetricCard(
                          title: 'Top 10',
                          value: '$top10',
                          subtitle: 'First page',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: RankMetricCard(
                          title: 'Avg. Rank',
                          value: avg > 0 ? avg.toStringAsFixed(1) : '—',
                          subtitle: 'Verified SERP',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Actions bar (Export Reports & Add Keyword)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 16,
                        ),
                        label: const Text('Export PDF'),
                        onPressed: keywords.isEmpty
                            ? null
                            : () => _exportPdf(context, website, keywords),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        label: const Text('Export CSV'),
                        onPressed: keywords.isEmpty
                            ? null
                            : () => _exportCsv(context, website, keywords),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Add Keyword',
                        onPressed: () =>
                            _openAddKeywordDialog(context, ref, website.id!),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Keyword List Header
                  const Text(
                    'Tracked Keywords',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (keywords.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: EmptyStateView(
                        icon: Icons.search,
                        title: 'No Keywords Added',
                        description:
                            'Add search queries you want to monitor for ${website.domain}.',
                        actionLabel: 'Add First Keyword',
                        onAction: () =>
                            _openAddKeywordDialog(context, ref, website.id!),
                      ),
                    )
                  else
                    ...keywords.map(
                      (k) => _KeywordTile(keyword: k, websiteId: website.id!),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
  }

  void _openAddKeywordDialog(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
  ) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Add Keyword', style: AppTextStyles.titleLarge),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. best flutter developer',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                await ref
                    .read(keywordsFamilyProvider(websiteId).notifier)
                    .addKeyword(keywordText: text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
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

class _KeywordTile extends ConsumerWidget {
  final Keyword keyword;
  final int websiteId;

  const _KeywordTile({required this.keyword, required this.websiteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          RankingBadge(
            position: keyword.latestPosition,
            delta: keyword.positionDelta,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(keyword.keywordText, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  keyword.targetCity != null
                      ? '${keyword.targetCity}, ${keyword.targetCountry}'
                      : keyword.targetCountry,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppColors.accent),
            tooltip: 'Log SERP Position',
            onPressed: () async {
              final updated = await showDialog<bool>(
                context: context,
                builder: (_) =>
                    LogRankDialog(keyword: keyword, websiteId: websiteId),
              );
              if (updated == true) {
                ref
                    .read(keywordsFamilyProvider(websiteId).notifier)
                    .loadKeywords();
              }
            },
          ),
        ],
      ),
    );
  }
}
