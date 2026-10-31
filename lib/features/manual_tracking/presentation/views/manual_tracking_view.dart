import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/cards/ranking_badge.dart';
import 'package:rankscope/shared/widgets/dialogs/log_rank_dialog.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';
import 'package:rankscope/shared/widgets/surfaces/glass_container.dart';

class ManualTrackingView extends ConsumerStatefulWidget {
  const ManualTrackingView({super.key});

  @override
  ConsumerState<ManualTrackingView> createState() => _ManualTrackingViewState();
}

class _ManualTrackingViewState extends ConsumerState<ManualTrackingView> {
  final _searchController = TextEditingController();
  String _filter = '';

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
        title: const Text('SERP Rank Audit', style: AppTextStyles.titleLarge),
      ),
      body: websitesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (websites) {
          final activeWebsite = websites.findActive(selectedSiteId);
          if (activeWebsite == null) {
            return const EmptyStateView(
              icon: Icons.track_changes,
              title: 'No Properties Available',
              description: 'Add a website on the Overview tab to begin manual SERP tracking.',
            );
          }

          final keywordsState = ref.watch(
            keywordsFamilyProvider(activeWebsite.id!),
          );

          return Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _filter = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search keywords in ${activeWebsite.domain}...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              Expanded(
                child: keywordsState.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (keywords) {
                    final filtered = keywords.where((k) {
                      return k.keywordText.toLowerCase().contains(_filter);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.search_off,
                        title: 'No Matching Keywords',
                        description: 'No keywords match your search query.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final kw = filtered[index];
                        return GlassContainer(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                          child: Row(
                            children: [
                              RankingBadge(
                                position: kw.latestPosition,
                                delta: kw.positionDelta,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kw.keywordText,
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      kw.targetCity != null
                                          ? '${kw.targetCity}, ${kw.targetCountry}'
                                          : kw.targetCountry,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () async {
                                  final res = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => LogRankDialog(
                                      keyword: kw,
                                      websiteId: activeWebsite.id!,
                                    ),
                                  );
                                  if (res == true) {
                                    ref
                                        .read(
                                          keywordsFamilyProvider(
                                            activeWebsite.id!,
                                          ).notifier,
                                        )
                                        .loadKeywords();
                                  }
                                },
                                child: const Text('Log Rank'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
