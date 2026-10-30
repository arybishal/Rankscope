import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/keywords/presentation/views/keyword_details_view.dart';
import 'package:rankscope/features/reporting/data/generators/csv_report_generator.dart';
import 'package:rankscope/features/reporting/data/generators/pdf_report_generator.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/cards/rank_metric_card.dart';
import 'package:rankscope/shared/widgets/cards/ranking_badge.dart';
import 'package:rankscope/shared/widgets/dialogs/add_keyword_dialog.dart';
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

enum _KeywordFilter {
  all,
  ranking,
  notRanking,
  improved,
  declined,
  newKeywords,
  lostKeywords,
  cannibalization,
  paused,
}

enum _SortOption {
  bestRank,
  worstRank,
  biggestGain,
  biggestDrop,
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
  String _selectedEngine = 'All'; // 'All', 'Google', 'Bing'
  _KeywordFilter _filter = _KeywordFilter.all;
  _SortOption _sort = _SortOption.bestRank;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keywordsState = ref.watch(keywordsFamilyProvider(widget.website.id!));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref
            .read(keywordsFamilyProvider(widget.website.id!).notifier)
            .loadKeywords();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Website Selector & Quick Actions
          _buildWebsiteSelectorRow(context),
          const SizedBox(height: AppSpacing.md),

          // Search Engine Switcher Tabs (All / Google / Bing)
          _buildSearchEngineFilterTabs(),
          const SizedBox(height: AppSpacing.md),

          // KPI Intelligence Grid
          keywordsState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (e, _) => Text('Error loading keywords: $e'),
            data: (keywords) {
              return _buildKpiAndKeywordList(context, keywords);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteSelectorRow(BuildContext context) {
    return Row(
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
                value: widget.website.id,
                isExpanded: true,
                dropdownColor: AppColors.surfacePrimary,
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
                    ref.read(selectedWebsiteIdProvider.notifier).select(id);
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

  Widget _buildSearchEngineFilterTabs() {
    return Row(
      children: [
        _buildEngineChip('All Engines', 'All', Icons.apps),
        const SizedBox(width: AppSpacing.xs),
        _buildEngineChip('Google', 'Google', Icons.search),
        const SizedBox(width: AppSpacing.xs),
        _buildEngineChip('Bing', 'Bing', Icons.travel_explore),
      ],
    );
  }

  Widget _buildEngineChip(String label, String value, IconData icon) {
    final isSelected = _selectedEngine == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedEngine = value),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFEFF6FF)
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiAndKeywordList(
    BuildContext context,
    List<Keyword> allKeywords,
  ) {
    // Engine scope filter
    final engineKeywords = _selectedEngine == 'All'
        ? allKeywords
        : allKeywords.where((k) => k.searchEngine == _selectedEngine).toList();

    final total = engineKeywords.length;
    final rankingCount = engineKeywords
        .where(
          (k) =>
              k.positionFor(_selectedEngine) != null &&
              k.positionFor(_selectedEngine)! > 0,
        )
        .length;
    final notRankingCount = engineKeywords
        .where((k) => k.positionFor(_selectedEngine) == 0)
        .length;
    final improvedCount = engineKeywords
        .where((k) => k.deltaFor(_selectedEngine) > 0)
        .length;
    final declinedCount = engineKeywords
        .where((k) => k.deltaFor(_selectedEngine) < 0)
        .length;
    final cannibalizationCount = engineKeywords
        .where((k) => k.hasCannibalization)
        .length;
    final newCount = engineKeywords.where((k) => k.isNew).length;
    final lostCount = engineKeywords.where((k) => k.isLost).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1st Row of KPIs
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _filter = _KeywordFilter.all),
                child: RankMetricCard(
                  title: 'Tracked',
                  value: '$total',
                  subtitle: _selectedEngine == 'All'
                      ? 'All Engines'
                      : _selectedEngine,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _filter = _KeywordFilter.ranking),
                child: RankMetricCard(
                  title: 'Ranking',
                  value: '$rankingCount',
                  subtitle: 'Positions 1-100',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 2nd Row of KPIs
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () =>
                    setState(() => _filter = _KeywordFilter.notRanking),
                child: RankMetricCard(
                  title: 'Not Ranking',
                  value: '$notRankingCount',
                  subtitle: 'Position 0',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _filter = _KeywordFilter.improved),
                child: RankMetricCard(
                  title: 'Improved',
                  value: '+$improvedCount',
                  subtitle: 'Rank Gains',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 3rd Row of KPIs (Cannibalization / Movements)
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _filter = _KeywordFilter.declined),
                child: RankMetricCard(
                  title: 'Declined',
                  value: '-$declinedCount',
                  subtitle: 'Rank Drops',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: () =>
                    setState(() => _filter = _KeywordFilter.cannibalization),
                child: RankMetricCard(
                  title: 'Cannibalization',
                  value: '$cannibalizationCount',
                  subtitle: 'Alerts Detected',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Actions Bar (PDF, CSV Export & Add Keyword)
        Row(
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
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.textPrimary),
              tooltip: 'Add Keyword',
              onPressed: () =>
                  _openAddKeywordDialog(context, ref, widget.website.id!),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Search Input
        TextField(
          controller: _searchController,
          onChanged: (val) =>
              setState(() => _searchQuery = val.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search queries or landing pages...',
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
        const SizedBox(height: AppSpacing.sm),

        // Horizontal Category Filter Chips & Sort Dropdown
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChoice('All', _KeywordFilter.all, total),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Ranking',
                _KeywordFilter.ranking,
                rankingCount,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Not Ranking (0)',
                _KeywordFilter.notRanking,
                notRankingCount,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Improved (▲)',
                _KeywordFilter.improved,
                improvedCount,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Declined (▼)',
                _KeywordFilter.declined,
                declinedCount,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice('New', _KeywordFilter.newKeywords, newCount),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Lost',
                _KeywordFilter.lostKeywords,
                lostCount,
              ),
              const SizedBox(width: 6),
              _buildFilterChoice(
                'Cannibalization',
                _KeywordFilter.cannibalization,
                cannibalizationCount,
              ),
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
            const Text('Tracked Keywords', style: AppTextStyles.titleMedium),
            DropdownButtonHideUnderline(
              child: DropdownButton<_SortOption>(
                value: _sort,
                items: const [
                  DropdownMenuItem(
                    value: _SortOption.bestRank,
                    child: Text('Sort: Best Rank'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.worstRank,
                    child: Text('Sort: Worst Rank'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.biggestGain,
                    child: Text('Sort: Biggest Gain'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.biggestDrop,
                    child: Text('Sort: Biggest Drop'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.alphabetical,
                    child: Text('Sort: Alphabetical'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.recentlyChecked,
                    child: Text('Sort: Recently Checked'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sort = val);
                },
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Filtered and Sorted Keyword List
        _buildKeywordItemsList(context, engineKeywords),
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
        color: isSelected ? AppColors.surfacePrimary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = filterValue);
      },
    );
  }

  Widget _buildKeywordItemsList(BuildContext context, List<Keyword> keywords) {
    // 1. Filter by category
    List<Keyword> filtered = keywords.where((k) {
      if (_searchQuery.isNotEmpty) {
        final matchesText = k.keywordText.toLowerCase().contains(_searchQuery);
        final matchesUrl =
            k.rankingUrl?.toLowerCase().contains(_searchQuery) ?? false;
        final matchesTarget =
            k.targetUrl?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchesText && !matchesUrl && !matchesTarget) return false;
      }

      final pos = k.positionFor(_selectedEngine);
      final delta = k.deltaFor(_selectedEngine);

      switch (_filter) {
        case _KeywordFilter.all:
          return true;
        case _KeywordFilter.ranking:
          return pos != null && pos > 0;
        case _KeywordFilter.notRanking:
          return pos == 0;
        case _KeywordFilter.improved:
          return delta > 0;
        case _KeywordFilter.declined:
          return delta < 0;
        case _KeywordFilter.newKeywords:
          return k.isNew;
        case _KeywordFilter.lostKeywords:
          return k.isLost;
        case _KeywordFilter.cannibalization:
          return k.hasCannibalization;
        case _KeywordFilter.paused:
          return !k.isActive;
      }
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final posA = a.positionFor(_selectedEngine) ?? 999;
      final posB = b.positionFor(_selectedEngine) ?? 999;
      final deltaA = a.deltaFor(_selectedEngine);
      final deltaB = b.deltaFor(_selectedEngine);

      switch (_sort) {
        case _SortOption.bestRank:
          return posA.compareTo(posB);
        case _SortOption.worstRank:
          return posB.compareTo(posA);
        case _SortOption.biggestGain:
          return deltaB.compareTo(deltaA);
        case _SortOption.biggestDrop:
          return deltaA.compareTo(deltaB);
        case _SortOption.alphabetical:
          return a.keywordText.toLowerCase().compareTo(
            b.keywordText.toLowerCase(),
          );
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
          title: keywords.isEmpty
              ? 'No Keywords Added'
              : 'No Matching Keywords',
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

    return Column(
      children: filtered.map((k) {
        return _KeywordTile(
          keyword: k,
          website: widget.website,
          selectedEngine: _selectedEngine,
        );
      }).toList(),
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

class _KeywordTile extends ConsumerWidget {
  final Keyword keyword;
  final Website website;
  final String selectedEngine;

  const _KeywordTile({
    required this.keyword,
    required this.website,
    required this.selectedEngine,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = keyword.positionFor(selectedEngine);
    final delta = keyword.deltaFor(selectedEngine);

    String? statusLabel;
    if (!keyword.isActive) {
      statusLabel = 'Paused';
    } else if (pos == null) {
      statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RankingBadge(
                    position: pos,
                    delta: delta,
                    statusLabel: statusLabel,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                keyword.keywordText,
                                style: AppTextStyles.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              keyword.searchEngine == 'Bing'
                                  ? Icons.travel_explore
                                  : Icons.search,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              keyword.targetCity != null
                                  ? '${keyword.targetCity}, ${keyword.targetCountry}'
                                  : keyword.targetCountry,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(width: 6),
                            Text('•', style: AppTextStyles.bodySmall),
                            const SizedBox(width: 6),
                            Text(
                              keyword.device,
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (val) {
                      switch (val) {
                        case 'log_rank':
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
                        value: 'log_rank',
                        child: Row(
                          children: [
                            Icon(Icons.add_chart, size: 18),
                            SizedBox(width: 8),
                            Text('Log SERP Rank'),
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
                            const SizedBox(width: 8),
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

              // Ranking URL indicator
              if (keyword.rankingUrl != null &&
                  keyword.rankingUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        keyword.rankingUrl!,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Badges for New, Lost, Cannibalization
              if (keyword.isNew ||
                  keyword.isLost ||
                  keyword.isRecovered ||
                  keyword.hasCannibalization) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (keyword.isNew)
                      _BadgeChip(
                        label: 'NEW',
                        bgColor: const Color(0xFFEFF6FF),
                        textColor: AppColors.accent,
                      ),
                    if (keyword.isLost)
                      _BadgeChip(
                        label: 'LOST',
                        bgColor: const Color(0xFFFEF2F2),
                        textColor: AppColors.rankDrop,
                      ),
                    if (keyword.isRecovered)
                      _BadgeChip(
                        label: 'RECOVERED',
                        bgColor: const Color(0xFFF0FDF4),
                        textColor: const Color(0xFF16A34A),
                      ),
                    if (keyword.hasCannibalization)
                      _BadgeChip(
                        label: keyword.cannibalizationStatus == 'url_switching'
                            ? 'URL SWITCHING'
                            : 'CANNIBALIZATION',
                        bgColor: const Color(0xFFFFFBEB),
                        textColor: const Color(0xFFB45309),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _BadgeChip({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
