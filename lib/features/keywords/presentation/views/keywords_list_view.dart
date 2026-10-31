import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/cards/ranking_badge.dart';
import '../../../../shared/widgets/dialogs/add_keyword_dialog.dart';
import '../../../../shared/widgets/feedback/empty_state_view.dart';
import '../../../../shared/widgets/surfaces/glass_container.dart';
import '../../../websites/presentation/controllers/websites_controller.dart';
import '../controllers/keywords_controller.dart';
import 'keyword_details_view.dart';

enum _RankingBand { all, top3, top10, striking, beyond, unranked }

enum _SortOption {
  bestRank,
  worstRank,
  mostClicks,
  mostImpressions,
  alphabetical,
  recentSync,
}

class KeywordsListView extends ConsumerStatefulWidget {
  const KeywordsListView({super.key});

  @override
  ConsumerState<KeywordsListView> createState() => _KeywordsListViewState();
}

class _KeywordsListViewState extends ConsumerState<KeywordsListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedEngine = 'All'; // All, Google, Bing, Yandex
  _RankingBand _selectedBand = _RankingBand.all;
  _SortOption _sortOption = _SortOption.bestRank;

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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Keywords', style: AppTextStyles.titleLarge),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Keyword'),
        onPressed: () {
          final sites = websitesState.value ?? [];
          final active = sites.findActive(selectedSiteId);
          if (active != null && active.id != null) {
            showDialog(
              context: context,
              builder: (_) => AddKeywordDialog(websiteId: active.id!),
            );
          }
        },
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
              icon: Icons.key_outlined,
              title: 'No Website Selected',
              description: 'Register or select a website to track keyword rankings.',
              actionLabel: 'Manage Websites',
              onAction: () => context.push('/websites'),
            );
          }

          return _KeywordsWorkspace(
            website: activeWebsite,
            allWebsites: websites,
            searchQuery: _searchQuery,
            searchController: _searchController,
            selectedEngine: _selectedEngine,
            selectedBand: _selectedBand,
            sortOption: _sortOption,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            onEngineChanged: (e) => setState(() => _selectedEngine = e),
            onBandChanged: (b) => setState(() => _selectedBand = b),
            onSortChanged: (s) => setState(() => _sortOption = s),
          );
        },
      ),
    );
  }
}

class _KeywordsWorkspace extends ConsumerWidget {
  final Website website;
  final List<Website> allWebsites;
  final String searchQuery;
  final TextEditingController searchController;
  final String selectedEngine;
  final _RankingBand selectedBand;
  final _SortOption sortOption;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onEngineChanged;
  final ValueChanged<_RankingBand> onBandChanged;
  final ValueChanged<_SortOption> onSortChanged;

  const _KeywordsWorkspace({
    required this.website,
    required this.allWebsites,
    required this.searchQuery,
    required this.searchController,
    required this.selectedEngine,
    required this.selectedBand,
    required this.sortOption,
    required this.onSearchChanged,
    required this.onEngineChanged,
    required this.onBandChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordsState = ref.watch(keywordsFamilyProvider(website.id!));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref.read(keywordsFamilyProvider(website.id!).notifier).loadKeywords();
      },
      child: keywordsState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading keywords: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (keywords) {
          // 1. Text Search Filter
          List<Keyword> filtered = keywords.where((kw) {
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              final matchesText = kw.keywordText.toLowerCase().contains(q);
              final matchesTag = kw.tags.any((t) => t.toLowerCase().contains(q));
              final matchesTarget = (kw.targetUrl ?? '').toLowerCase().contains(q);
              if (!matchesText && !matchesTag && !matchesTarget) return false;
            }
            return true;
          }).toList();

          // 2. Ranking Band Filter
          filtered = filtered.where((kw) {
            final pos = kw.positionFor(selectedEngine);
            switch (selectedBand) {
              case _RankingBand.all:
                return true;
              case _RankingBand.top3:
                return pos != null && pos >= 1 && pos <= 3;
              case _RankingBand.top10:
                return pos != null && pos >= 4 && pos <= 10;
              case _RankingBand.striking:
                return pos != null && pos >= 11 && pos <= 20;
              case _RankingBand.beyond:
                return pos != null && pos >= 21 && pos <= 100;
              case _RankingBand.unranked:
                return pos == null || pos > 100;
            }
          }).toList();

          // 3. Sorting
          filtered.sort((a, b) {
            switch (sortOption) {
              case _SortOption.bestRank:
                final pA = a.positionFor(selectedEngine) ?? 9999;
                final pB = b.positionFor(selectedEngine) ?? 9999;
                return pA.compareTo(pB);
              case _SortOption.worstRank:
                final pA = a.positionFor(selectedEngine) ?? 0;
                final pB = b.positionFor(selectedEngine) ?? 0;
                return pB.compareTo(pA);
              case _SortOption.mostClicks:
                return b.totalClicks.compareTo(a.totalClicks);
              case _SortOption.mostImpressions:
                return b.totalImpressions.compareTo(a.totalImpressions);
              case _SortOption.alphabetical:
                return a.keywordText.toLowerCase().compareTo(b.keywordText.toLowerCase());
              case _SortOption.recentSync:
                final tA = a.updatedAt.millisecondsSinceEpoch;
                final tB = b.updatedAt.millisecondsSinceEpoch;
                return tB.compareTo(tA);
            }
          });

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 1. Website Switcher Row
              _buildWebsiteHeader(context, isDark, ref),
              const SizedBox(height: AppSpacing.md),

              // 2. Search & Sort Bar
              _buildSearchBar(context, isDark),
              const SizedBox(height: AppSpacing.sm),

              // 3. Engine Filter Chips (All, Google, Bing, Yandex)
              _buildEngineSelector(isDark),
              const SizedBox(height: AppSpacing.sm),

              // 4. Ranking Band Filter Chips
              _buildRankingBandSelector(isDark, keywords),
              const SizedBox(height: AppSpacing.md),

              // 5. Total Count & Filter Feedback
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filtered.length} of ${keywords.length} keywords',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  PopupMenuButton<_SortOption>(
                    icon: Icon(
                      Icons.sort,
                      size: 18,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    tooltip: 'Sort Keywords',
                    color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                    onSelected: onSortChanged,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: _SortOption.bestRank,
                        child: Text('Best Ranking First'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.worstRank,
                        child: Text('Worst Ranking First'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.mostClicks,
                        child: Text('Most Clicks'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.mostImpressions,
                        child: Text('Most Impressions'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.alphabetical,
                        child: Text('Alphabetical (A-Z)'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.recentSync,
                        child: Text('Recently Synced'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // 6. Keywords List Items
              if (filtered.isEmpty)
                _buildEmptyKeywords(isDark)
              else
                ...filtered.map((kw) => _buildKeywordCard(context, isDark, kw)),
              const SizedBox(height: 72), // FAB clearance
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

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search keyword, tag, or target URL...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              )
            : null,
      ),
    );
  }

  Widget _buildEngineSelector(bool isDark) {
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

  Widget _buildRankingBandSelector(bool isDark, List<Keyword> allKeywords) {
    final bands = <_RankingBand, String>{
      _RankingBand.all: 'All',
      _RankingBand.top3: 'Top 3 (1-3)',
      _RankingBand.top10: 'Top 10 (4-10)',
      _RankingBand.striking: 'Striking (11-20)',
      _RankingBand.beyond: 'Beyond (21-100)',
      _RankingBand.unranked: 'Unranked',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: bands.entries.map((entry) {
          final isSelected = selectedBand == entry.key;
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
              onSelected: (_) => onBandChanged(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyKeywords(bool isDark) {
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
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No Matching Keywords Found',
              style: AppTextStyles.titleMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try clearing filters or search terms, or add new keywords.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordCard(BuildContext context, bool isDark, Keyword kw) {
    final position = kw.positionFor(selectedEngine);
    final delta = kw.deltaFor(selectedEngine);

    // Identify if target URL doesn't match observed ranking URL
    final rankingUrl = kw.googleRankingUrl ?? kw.bingRankingUrl ?? kw.yandexRankingUrl;
    final bool hasMismatch = kw.targetUrl != null &&
        kw.targetUrl!.isNotEmpty &&
        rankingUrl != null &&
        rankingUrl.isNotEmpty &&
        kw.targetUrl != rankingUrl;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KeywordDetailsView(
              initialKeyword: kw,
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
              // Row 1: Keyword Text + Position Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kw.keywordText,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (kw.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: kw.tags.map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RankingBadge(position: position, delta: delta),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Search Engine Positions Strip
              Row(
                children: [
                  _engineBadge('G', kw.googlePosition, AppColors.engineGoogle, isDark),
                  const SizedBox(width: 6),
                  _engineBadge('B', kw.bingPosition, AppColors.engineBing, isDark),
                  const SizedBox(width: 6),
                  _engineBadge('Y', kw.yandexPosition, AppColors.engineYandex, isDark),
                  const Spacer(),
                  // Impressions & Clicks
                  Text(
                    '${kw.totalClicks} clicks · ${kw.totalImpressions} impr',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),

              // Row 3: Target URL & Ranking URL Mismatch Alert (if any)
              if (hasMismatch) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.rankDropLight.withAlpha(isDark ? 30 : 255),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.rankDrop.withAlpha(isDark ? 80 : 150),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.rankDrop),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Observed page differs from intended target URL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFFCA5A5) : AppColors.rankDrop,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
  }

  Widget _engineBadge(String letter, int? pos, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(isDark ? 100 : 70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            pos != null ? '#$pos' : '-',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
