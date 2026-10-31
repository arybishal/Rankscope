import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/bing_webmaster/presentation/controllers/bing_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/dialogs/add_website_dialog.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';

class WebsitesManagementView extends ConsumerStatefulWidget {
  const WebsitesManagementView({super.key});

  @override
  ConsumerState<WebsitesManagementView> createState() =>
      _WebsitesManagementViewState();
}

enum _FilterOption { all, myWebsites, competitors }

class _WebsitesManagementViewState
    extends ConsumerState<WebsitesManagementView> {
  _FilterOption _filter = _FilterOption.all;

  void _openAddWebsiteDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddWebsiteDialog());
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

  @override
  Widget build(BuildContext context) {
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Websites', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Website',
            onPressed: () => _openAddWebsiteDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Website'),
        onPressed: () => _openAddWebsiteDialog(context),
      ),
      body: websitesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (websites) {
          if (websites.isEmpty) {
            return EmptyStateView(
              icon: Icons.language,
              title: 'No Websites Registered',
              description: 'Add your primary business website or competitor websites to start monitoring search rankings.',
              actionLabel: 'Add Your First Website',
              onAction: () => _openAddWebsiteDialog(context),
            );
          }

          final activeWebsite = websites.findActive(selectedSiteId);

          final filteredWebsites = websites.where((w) {
            switch (_filter) {
              case _FilterOption.all:
                return true;
              case _FilterOption.myWebsites:
                return !w.isCompetitor;
              case _FilterOption.competitors:
                return w.isCompetitor;
            }
          }).toList();

          final myCount = websites.where((w) => !w.isCompetitor).length;
          final compCount = websites.where((w) => w.isCompetitor).length;

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              await ref.read(websitesProvider.notifier).loadWebsites();
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Filter Segment Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('All (${websites.length})'),
                        selected: _filter == _FilterOption.all,
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: _filter == _FilterOption.all
                              ? AppColors.surfacePrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _filter = _FilterOption.all);
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ChoiceChip(
                        label: Text('My Websites ($myCount)'),
                        selected: _filter == _FilterOption.myWebsites,
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: _filter == _FilterOption.myWebsites
                              ? AppColors.surfacePrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _filter = _FilterOption.myWebsites);
                          }
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ChoiceChip(
                        label: Text('Competitors ($compCount)'),
                        selected: _filter == _FilterOption.competitors,
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: _filter == _FilterOption.competitors
                              ? AppColors.surfacePrimary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _filter = _FilterOption.competitors);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (filteredWebsites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No websites in this category.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredWebsites.map((website) {
                    final isActive = activeWebsite?.id == website.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        onTap: () {
                          ref
                              .read(selectedWebsiteIdProvider.notifier)
                              .select(website.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: isActive
                                        ? AppColors.accent
                                        : AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                website.label,
                                                style:
                                                    AppTextStyles.titleMedium,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _TagBadge(
                                              isCompetitor:
                                                  website.isCompetitor,
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEFF6FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFBFDBFE,
                                                    ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Active',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.accent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          website.domain,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    tooltip: 'Edit Website',
                                    onPressed: () => _openEditWebsiteDialog(
                                      context,
                                      website,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.rankDrop,
                                    ),
                                    tooltip: 'Delete Website',
                                    onPressed: () => _confirmDeleteWebsite(
                                      context,
                                      ref,
                                      website,
                                    ),
                                  ),
                                ],
                              ),
                              if (website.notes != null &&
                                  website.notes!.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Padding(
                                  padding: const EdgeInsets.only(left: 28),
                                  child: Text(
                                    website.notes!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              Padding(
                                padding: const EdgeInsets.only(left: 28),
                                child: Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: 4,
                                  children: [
                                    if (website.gscPropertyId != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            size: 13,
                                            color: AppColors.googleBlue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'GSC: ${website.gscPropertyId}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.googleBlue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    _BingStatusBadge(domain: website.domain),
                                    if (website.yandexHostId != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            size: 13,
                                            color: AppColors.yandexRed,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Yandex: ${website.yandexHostId}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.yandexRed,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80), // spacing for FAB
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final bool isCompetitor;

  const _TagBadge({required this.isCompetitor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isCompetitor ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        border: Border.all(
          color: isCompetitor
              ? const Color(0xFFFECACA)
              : const Color(0xFFBBF7D0),
        ),
      ),
      child: Text(
        isCompetitor ? 'Competitor' : 'Primary',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isCompetitor ? AppColors.rankDrop : AppColors.rankGain,
        ),
      ),
    );
  }
}

class _BingStatusBadge extends ConsumerWidget {
  final String domain;

  const _BingStatusBadge({required this.domain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(bingPropertyStatusProvider(domain));

    return statusAsync.maybeWhen(
      data: (result) {
        if (result.status == BingVerificationStatus.verifiedAndMatched) {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 14, color: AppColors.rankGain),
              SizedBox(width: 4),
              Text(
                'Bing Verified',
                style: TextStyle(fontSize: 11, color: AppColors.rankGain),
              ),
            ],
          );
        } else if (result.status ==
            BingVerificationStatus.locallyAddedNotVerified) {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: Color(0xFFD97706)),
              SizedBox(width: 4),
              Text(
                'Bing Verification Pending',
                style: TextStyle(fontSize: 11, color: Color(0xFFD97706)),
              ),
            ],
          );
        } else if (result.status == BingVerificationStatus.propertyNotFound) {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              SizedBox(width: 4),
              Text(
                'Not in Bing Account',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
