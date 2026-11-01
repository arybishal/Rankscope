import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/cards/ranking_badge.dart';
import '../../../../shared/widgets/dialogs/add_keyword_dialog.dart';
import '../../../../shared/widgets/dialogs/log_rank_dialog.dart';
import '../../../../shared/widgets/dialogs/manage_keyword_groups_dialog.dart';
import '../../../../shared/widgets/dialogs/move_keyword_group_dialog.dart';
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

class KeywordsListView extends ConsumerStatefulWidget {
  const KeywordsListView({super.key});

  @override
  ConsumerState<KeywordsListView> createState() => _KeywordsListViewState();
}

class _KeywordsListViewState extends ConsumerState<KeywordsListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedEngine = 'All'; // All, Google, Bing, Yandex
  int? _selectedGroupId; // null = all groups, -1 = ungrouped, > 0 = specific group
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
              Icons.folder_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            tooltip: 'Manage Groups',
            onPressed: () {
              final sites = websitesState.value ?? [];
              final active = sites.findActive(selectedSiteId);
              if (active != null && active.id != null) {
                showDialog(
                  context: context,
                  builder: (_) => ManageKeywordGroupsDialog(websiteId: active.id!),
                );
              }
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
            selectedGroupId: _selectedGroupId,
            selectedBand: _selectedBand,
            sortOption: _sortOption,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            onEngineChanged: (e) => setState(() => _selectedEngine = e),
            onGroupChanged: (g) => setState(() => _selectedGroupId = g),
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
  final int? selectedGroupId;
  final _RankingBand selectedBand;
  final _SortOption sortOption;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onEngineChanged;
  final ValueChanged<int?> onGroupChanged;
  final ValueChanged<_RankingBand> onBandChanged;
  final ValueChanged<_SortOption> onSortChanged;

  const _KeywordsWorkspace({
    required this.website,
    required this.allWebsites,
    required this.searchQuery,
    required this.searchController,
    required this.selectedEngine,
    required this.selectedGroupId,
    required this.selectedBand,
    required this.sortOption,
    required this.onSearchChanged,
    required this.onEngineChanged,
    required this.onGroupChanged,
    required this.onBandChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordsState = ref.watch(keywordsFamilyProvider(website.id!));
    final groupsState = ref.watch(keywordGroupsFamilyProvider(website.id!));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await ref.read(keywordsFamilyProvider(website.id!).notifier).loadKeywords();
        ref.invalidate(keywordGroupsFamilyProvider(website.id!));
      },
      child: keywordsState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Text('Error loading keywords: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (keywords) {
          final groups = groupsState.value ?? [];

          // 1. Group Filter
          List<Keyword> filtered = keywords.where((kw) {
            if (selectedGroupId == -1) {
              return kw.groupId == null;
            } else if (selectedGroupId != null && selectedGroupId! > 0) {
              return kw.groupId == selectedGroupId;
            }
            return true;
          }).toList();

          // 2. Text Search Filter (keyword text, tag, target URL, ranking URL)
          filtered = filtered.where((kw) {
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              final matchesText = kw.keywordText.toLowerCase().contains(q);
              final matchesTag = kw.tags.any((t) => t.toLowerCase().contains(q));
              final matchesTarget = (kw.targetUrl ?? '').toLowerCase().contains(q);
              final matchesRanking = (kw.rankingUrl ?? '').toLowerCase().contains(q);
              if (!matchesText && !matchesTag && !matchesTarget && !matchesRanking) {
                return false;
              }
            }
            return true;
          }).toList();

          // 3. Ranking Band Filter
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

          // 4. Sorting
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

              // 2. Keyword Group Filter Chips Row
              _buildGroupSelector(context, isDark, keywords, groups),
              const SizedBox(height: AppSpacing.sm),

              // 3. Group / Selected Subset Summary Header Card
              _buildGroupSummaryCard(context, isDark, filtered, groups),
              const SizedBox(height: AppSpacing.md),

              // 4. Search Bar
              _buildSearchBar(context, isDark),
              const SizedBox(height: AppSpacing.sm),

              // 5. Engine Filter Chips (All, Google, Bing, Yandex)
              _buildEngineSelector(isDark),
              const SizedBox(height: AppSpacing.sm),

              // 6. Ranking Band Filter Chips
              _buildRankingBandSelector(isDark, keywords),
              const SizedBox(height: AppSpacing.md),

              // 7. Total Count & Sort Row
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

              // 8. Keywords List Items
              if (filtered.isEmpty)
                _buildEmptyKeywords(isDark)
              else
                ...filtered.map((kw) => _buildKeywordCard(context, isDark, kw, groups, ref)),
              const SizedBox(height: 72), // FAB clearance
            ],
          );
        },
      ),
    );
  }

  // --- Group Selector Chips ---

  Widget _buildGroupSelector(
    BuildContext context,
    bool isDark,
    List<Keyword> allKeywords,
    List<KeywordGroup> groups,
  ) {
    final ungroupedCount = allKeywords.where((k) => k.groupId == null).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All Groups Chip
          FilterChip(
            label: Text('All Groups (${allKeywords.length})'),
            selected: selectedGroupId == null,
            selectedColor: AppColors.accent.withAlpha(isDark ? 50 : 30),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selectedGroupId == null ? FontWeight.bold : FontWeight.w500,
              color: selectedGroupId == null
                  ? AppColors.accent
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
            backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
            onSelected: (_) => onGroupChanged(null),
          ),
          const SizedBox(width: 6),

          // Ungrouped Chip
          FilterChip(
            label: Text('Ungrouped ($ungroupedCount)'),
            selected: selectedGroupId == -1,
            selectedColor: const Color(0xFF64748B).withAlpha(isDark ? 50 : 30),
            avatar: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF64748B),
              ),
            ),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selectedGroupId == -1 ? FontWeight.bold : FontWeight.w500,
              color: selectedGroupId == -1
                  ? (isDark ? Colors.white : const Color(0xFF334155))
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
            backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
            onSelected: (_) => onGroupChanged(-1),
          ),
          const SizedBox(width: 6),

          // Individual Group Chips
          ...groups.map((g) {
            final isSelected = selectedGroupId == g.id;
            final color = _parseHex(g.colorHex);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text('${g.name} (${g.keywordCount})'),
                selected: isSelected,
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                selectedColor: color.withAlpha(isDark ? 50 : 30),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? color
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
                onSelected: (_) => onGroupChanged(g.id),
              ),
            );
          }),

          // Manage Groups Button
          ActionChip(
            avatar: const Icon(Icons.settings_outlined, size: 14, color: AppColors.accent),
            label: const Text('Manage Groups'),
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
            backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ManageKeywordGroupsDialog(websiteId: website.id!),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Group Summary Header Card ---

  Widget _buildGroupSummaryCard(
    BuildContext context,
    bool isDark,
    List<Keyword> currentKeywords,
    List<KeywordGroup> groups,
  ) {
    String groupTitle = 'All Tracked Keywords';
    Color groupColor = AppColors.accent;

    if (selectedGroupId == -1) {
      groupTitle = 'Ungrouped Keywords';
      groupColor = const Color(0xFF64748B);
    } else if (selectedGroupId != null && selectedGroupId! > 0) {
      final matching = groups.where((g) => g.id == selectedGroupId);
      if (matching.isNotEmpty) {
        groupTitle = 'Group: ${matching.first.name}';
        groupColor = _parseHex(matching.first.colorHex);
      }
    }

    // Compute real-time aggregates
    int totalImpressions = 0;
    int totalClicks = 0;
    double posSum = 0;
    int rankedCount = 0;

    for (final kw in currentKeywords) {
      totalImpressions += kw.totalImpressions;
      totalClicks += kw.totalClicks;
      final pos = kw.positionFor(selectedEngine) ??
          (kw.averagePositionFor(selectedEngine)?.round());
      if (pos != null && pos > 0) {
        posSum += pos;
        rankedCount++;
      }
    }

    final double? avgPos = rankedCount > 0 ? (posSum / rankedCount) : null;
    final double ctr = totalImpressions > 0 ? (totalClicks / totalImpressions) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: groupColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupTitle,
                  style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${currentKeywords.length} keywords',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  title: 'Avg Position',
                  value: avgPos != null ? '#${avgPos.toStringAsFixed(1)}' : 'Unranked',
                  color: avgPos != null ? AppColors.accent : const Color(0xFF64748B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricMini(
                  title: 'Impressions',
                  value: _formatNumber(totalImpressions),
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricMini(
                  title: 'Clicks',
                  value: _formatNumber(totalClicks),
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricMini(
                  title: 'CTR',
                  value: '${(ctr * 100).toStringAsFixed(1)}%',
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMini({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  // --- Keyword Card Item ---

  Widget _buildKeywordCard(
    BuildContext context,
    bool isDark,
    Keyword kw,
    List<KeywordGroup> groups,
    WidgetRef ref,
  ) {
    final position = kw.positionFor(selectedEngine);
    final delta = kw.deltaFor(selectedEngine);
    final avgPos = kw.averagePositionFor(selectedEngine);

    // Identify matching group
    KeywordGroup? assignedGroup;
    if (kw.groupId != null) {
      final match = groups.where((g) => g.id == kw.groupId);
      if (match.isNotEmpty) assignedGroup = match.first;
    }

    // Identify if target URL doesn't match observed ranking URL
    final rankingUrl = kw.googleRankingUrl ?? kw.bingRankingUrl ?? kw.yandexRankingUrl;
    final bool hasMismatch = kw.targetUrl != null &&
        kw.targetUrl!.isNotEmpty &&
        rankingUrl != null &&
        rankingUrl.isNotEmpty &&
        kw.targetUrl != rankingUrl;

    final firstDateStr = kw.firstRankedAt != null
        ? DateFormat('MMM d, yyyy').format(kw.firstRankedAt!)
        : 'Pending check';

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
            // Row 1: Keyword Text + Group Badge + Ranking Badge + Actions Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              kw.keywordText,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          // Group Badge
                          if (assignedGroup != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _parseHex(assignedGroup.colorHex).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _parseHex(assignedGroup.colorHex),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    assignedGroup.name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _parseHex(assignedGroup.colorHex),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Keyword Tags
                          ...kw.tags.map((t) {
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
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Position Display (Exact SERP position or Search Console Average Position)
                if (position != null && position > 0)
                  RankingBadge(position: position, delta: delta)
                else if (avgPos != null && avgPos > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'Avg #${avgPos.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                else
                  RankingBadge(position: null, delta: 0),

                // Actions Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                  onSelected: (val) async {
                    if (val == 'details') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KeywordDetailsView(
                            initialKeyword: kw,
                            website: website,
                          ),
                        ),
                      );
                    } else if (val == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => AddKeywordDialog(
                          websiteId: website.id!,
                          initialKeyword: kw,
                        ),
                      );
                    } else if (val == 'move_group') {
                      showDialog(
                        context: context,
                        builder: (_) => MoveKeywordGroupDialog(
                          websiteId: website.id!,
                          keywordIds: [kw.id!],
                          keywordSummaryText: kw.keywordText,
                          currentGroupId: kw.groupId,
                        ),
                      );
                    } else if (val == 'log_rank') {
                      showDialog(
                        context: context,
                        builder: (_) => LogRankDialog(
                          keyword: kw,
                          websiteId: website.id!,
                        ),
                      );
                    } else if (val == 'delete') {
                      _confirmDeleteKeyword(context, kw, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move_group',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_move_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Move to Group'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Keyword'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'log_rank',
                      child: Row(
                        children: [
                          Icon(Icons.add_chart_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Log SERP Rank'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: AppColors.rankDrop),
                          SizedBox(width: 8),
                          Text('Delete Keyword', style: TextStyle(color: AppColors.rankDrop)),
                        ],
                      ),
                    ),
                  ],
                ),
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

            // Row 4: Dates
            const SizedBox(height: 6),
            Text(
              'First recorded: $firstDateStr',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteKeyword(BuildContext context, Keyword kw, WidgetRef ref) {
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
          'All associated rank movement history and observations will be removed.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rankDrop),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(keywordsFamilyProvider(website.id!).notifier)
                  .deleteKeyword(kw.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Keyword "${kw.keywordText}" deleted.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
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
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(eng),
              selected: isSelected,
              selectedColor: AppColors.accent,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
              onSelected: (_) => onEngineChanged(eng),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingBandSelector(bool isDark, List<Keyword> keywords) {
    final bands = [
      _RankingBand.all,
      _RankingBand.top3,
      _RankingBand.top10,
      _RankingBand.striking,
      _RankingBand.beyond,
      _RankingBand.unranked,
    ];

    String bandLabel(_RankingBand b) {
      switch (b) {
        case _RankingBand.all:
          return 'All Bands';
        case _RankingBand.top3:
          return 'Top 3';
        case _RankingBand.top10:
          return 'Top 10';
        case _RankingBand.striking:
          return 'Striking (11-20)';
        case _RankingBand.beyond:
          return 'Beyond 20';
        case _RankingBand.unranked:
          return 'Unranked';
      }
    }

    int bandCount(_RankingBand b) {
      return keywords.where((kw) {
        final pos = kw.positionFor(selectedEngine);
        switch (b) {
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
      }).length;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: bands.map((band) {
          final isSelected = selectedBand == band;
          final count = bandCount(band);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text('${bandLabel(band)} ($count)'),
              selected: isSelected,
              selectedColor: AppColors.accent.withAlpha(isDark ? 50 : 30),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.accent
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.surfaceSecondary,
              onSelected: (_) => onBandChanged(band),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyKeywords(bool isDark) {
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
            pos != null && pos > 0 ? '#$pos' : '-',
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
