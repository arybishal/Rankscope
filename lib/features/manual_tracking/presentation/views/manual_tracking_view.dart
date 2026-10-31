import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/utils/date_formatter.dart';
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/shared/widgets/cards/ranking_badge.dart';
import 'package:rankscope/shared/widgets/dialogs/log_rank_dialog.dart';
import 'package:rankscope/shared/widgets/feedback/empty_state_view.dart';
import 'package:rankscope/shared/widgets/surfaces/glass_container.dart';

final isGoogleConnectedFutureProvider = FutureProvider<bool>((ref) async {
  final storage = SecureStorageService();
  final token = await storage.getGscAccessToken();
  final refresh = await storage.getGscRefreshToken();
  return (token != null && token.trim().isNotEmpty) ||
      (refresh != null && refresh.trim().isNotEmpty);
});

class ManualTrackingView extends ConsumerStatefulWidget {
  const ManualTrackingView({super.key});

  @override
  ConsumerState<ManualTrackingView> createState() => _ManualTrackingViewState();
}

class _ManualTrackingViewState extends ConsumerState<ManualTrackingView> {
  final _searchController = TextEditingController();
  String _filter = '';
  String _engineFilter = 'All'; // 'All', 'Google', 'Bing', 'Yandex', 'Manual'
  String _sortBy = 'Google Position'; // 'Google Position', 'Keyword', 'Impressions', 'Clicks', 'Manual Rank'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSync(int websiteId, String domain) async {
    final result = await ref
        .read(searchPerformanceSyncProvider.notifier)
        .syncPerformance(websiteId: websiteId, domain: domain);

    if (!mounted) return;

    if (result != null) {
      final msg = 'Sync Complete: '
          '${result.googleStatusMessage ?? "Google ready"} • '
          '${result.matchedKeywords}/${result.totalKeywords} keywords matched';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rankGain,
        ),
      );
    } else {
      final err = ref.read(searchPerformanceSyncProvider).errorMessage ??
          'Sync failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.rankDrop),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final websitesState = ref.watch(websitesProvider);
    final selectedSiteId = ref.watch(selectedWebsiteIdProvider);
    final syncState = ref.watch(searchPerformanceSyncProvider);
    final googleConnectedAsync = ref.watch(isGoogleConnectedFutureProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('SERP Audit', style: AppTextStyles.titleLarge),
        actions: [
          websitesState.maybeWhen(
            data: (websites) {
              final activeWebsite = websites.findActive(selectedSiteId);
              if (activeWebsite == null) return const SizedBox.shrink();
              return IconButton(
                icon: syncState.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sync Google & Search Data',
                onPressed: syncState.isSyncing
                    ? null
                    : () => _handleSync(
                          activeWebsite.id!,
                          activeWebsite.domain,
                        ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
              description:
                  'Add a website on the Overview tab to view Search Console and SERP rankings.',
            );
          }

          final keywordsState = ref.watch(
            keywordsFamilyProvider(activeWebsite.id!),
          );

          return RefreshIndicator(
            onRefresh: () => _handleSync(
              activeWebsite.id!,
              activeWebsite.domain,
            ),
            child: Column(
              children: [
                // Informative Google Connection Banner if not yet configured
                googleConnectedAsync.maybeWhen(
                  data: (isGoogleConnected) {
                    if (isGoogleConnected) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Connect Google Search Console in Settings to automatically sync average ranking positions and queries.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => context.push('/settings'),
                            child: const Text('Setup'),
                          ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                // Search & Filter Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
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

                // Engine Filter Chips & Sort Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _buildEngineChip('All', 'All Sources', Icons.apps),
                      const SizedBox(width: 6),
                      _buildEngineChip(
                        'Google',
                        'Google (GSC)',
                        Icons.search,
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      _buildEngineChip(
                        'Manual',
                        'Manual Only',
                        Icons.edit_note,
                        color: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 6),
                      _buildEngineChip(
                        'Bing',
                        'Bing',
                        Icons.travel_explore,
                        color: const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 6),
                      _buildEngineChip(
                        'Yandex',
                        'Yandex',
                        Icons.language,
                        color: const Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 24,
                        width: 1,
                        color: isDark
                            ? AppColors.darkBorderSubtle
                            : AppColors.borderSubtle,
                      ),
                      const SizedBox(width: 12),
                      // Sort dropdown menu
                      PopupMenuButton<String>(
                        tooltip: 'Sort Keywords',
                        initialValue: _sortBy,
                        onSelected: (val) => setState(() => _sortBy = val),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceSecondary
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorderSubtle
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sort,
                                size: 14,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Sort: $_sortBy',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'Google Position',
                            child: Text('Google Avg Position'),
                          ),
                          const PopupMenuItem(
                            value: 'Keyword',
                            child: Text('Keyword (A-Z)'),
                          ),
                          const PopupMenuItem(
                            value: 'Impressions',
                            child: Text('Impressions'),
                          ),
                          const PopupMenuItem(
                            value: 'Clicks',
                            child: Text('Clicks'),
                          ),
                          const PopupMenuItem(
                            value: 'Manual Rank',
                            child: Text('Manual Rank'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                // Keywords List
                Expanded(
                  child: keywordsState.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (keywords) {
                      var filtered = keywords.where((k) {
                        final matchesSearch =
                            k.keywordText.toLowerCase().contains(_filter);
                        if (!matchesSearch) return false;

                        if (_engineFilter == 'Google') {
                          return k.googleAveragePosition != null &&
                              k.googleAveragePosition! > 0;
                        } else if (_engineFilter == 'Bing') {
                          return k.bingAveragePosition != null &&
                              k.bingAveragePosition! > 0;
                        } else if (_engineFilter == 'Yandex') {
                          return k.yandexAveragePosition != null &&
                              k.yandexAveragePosition! > 0;
                        } else if (_engineFilter == 'Manual') {
                          return k.latestPosition != null &&
                              k.latestPosition! > 0;
                        }
                        return true;
                      }).toList();

                      // Sort keywords
                      filtered.sort((a, b) {
                        switch (_sortBy) {
                          case 'Keyword':
                            return a.keywordText
                                .toLowerCase()
                                .compareTo(b.keywordText.toLowerCase());
                          case 'Impressions':
                            return b.googleImpressions
                                .compareTo(a.googleImpressions);
                          case 'Clicks':
                            return b.googleClicks.compareTo(a.googleClicks);
                          case 'Manual Rank':
                            final posA = a.latestPosition ?? 999;
                            final posB = b.latestPosition ?? 999;
                            return posA.compareTo(posB);
                          case 'Google Position':
                          default:
                            final posA = a.googleAveragePosition ?? 999.0;
                            final posB = b.googleAveragePosition ?? 999.0;
                            return posA.compareTo(posB);
                        }
                      });

                      if (filtered.isEmpty) {
                        return EmptyStateView(
                          icon: Icons.search_off,
                          title: 'No Matching Keywords',
                          description: _filter.isNotEmpty
                              ? 'No keywords match "$_filter".'
                              : 'No keywords match the selected filter.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final kw = filtered[index];
                          return _buildKeywordCard(
                            context,
                            isDark,
                            kw,
                            activeWebsite.id!,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEngineChip(
    String filterKey,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final isSelected = _engineFilter == filterKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? AppColors.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _engineFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark
                  ? AppColors.darkSurfaceSecondary
                  : AppColors.surfaceSecondary),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                    ? AppColors.darkBorderSubtle
                    : AppColors.borderSubtle),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? activeColor
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? activeColor
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordCard(
    BuildContext context,
    bool isDark,
    Keyword kw,
    int websiteId,
  ) {
    final hasGoogleData =
        kw.googleAveragePosition != null && kw.googleAveragePosition! > 0;
    final hasManualData = kw.latestPosition != null && kw.latestPosition! > 0;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keyword Title & Target Location Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kw.keywordText,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          kw.targetCity != null
                              ? '${kw.targetCity}, ${kw.targetCountry}'
                              : kw.targetCountry,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (kw.targetUrl != null &&
                            kw.targetUrl!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('•',
                              style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.textTertiary)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Target: ${kw.targetUrl}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 1. Google Search Console Section
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Google Search Console Average Position',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const Spacer(),
                    if (kw.googleSyncedAt != null)
                      Text(
                        DateFormatter.relativeTime(kw.googleSyncedAt!),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (hasGoogleData) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Avg #${kw.googleAveragePosition!.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildStatMetric(
                              'Impressions',
                              NumberFormat.compact().format(kw.googleImpressions),
                              isDark,
                            ),
                            _buildStatMetric(
                              'Clicks',
                              NumberFormat.compact().format(kw.googleClicks),
                              isDark,
                            ),
                            _buildStatMetric(
                              'CTR',
                              '${(kw.googleCtr * 100).toStringAsFixed(1)}%',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (kw.googleRankingUrl != null &&
                      kw.googleRankingUrl!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: kw.googleRankingUrl!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ranking URL copied to clipboard.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 13,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              kw.googleRankingUrl!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // Explicitly display "No Google data available" (NEVER display 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceSecondary
                          : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'No Google data available',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 2. Manual Observation Section (Stored Separately)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                if (hasManualData) ...[
                  RankingBadge(
                    position: kw.latestPosition,
                    delta: kw.positionDelta,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_note,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Manual Observation',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (hasManualData) ...[
                        Text(
                          'Point-in-time SERP Rank: #${kw.latestPosition}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (kw.lastCheckedAt != null)
                          Text(
                            'Recorded: ${DateFormatter.relativeTime(kw.lastCheckedAt!)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                      ] else ...[
                        Text(
                          'No manual observation recorded',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    final res = await showDialog<bool>(
                      context: context,
                      builder: (_) => LogRankDialog(
                        keyword: kw,
                        websiteId: websiteId,
                      ),
                    );
                    if (res == true) {
                      ref
                          .read(keywordsFamilyProvider(websiteId).notifier)
                          .loadKeywords();
                    }
                  },
                  child: const Text('Log Rank'),
                ),
              ],
            ),
          ),

          // 3. Optional Bing / Yandex rows if filtered or present
          if (_engineFilter == 'Bing' ||
              (kw.bingAveragePosition != null &&
                  kw.bingAveragePosition! > 0)) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildEngineSubRow(
              'Bing Webmaster Average Position',
              kw.bingAveragePosition,
              kw.bingClicks,
              kw.bingImpressions,
              kw.bingRankingUrl,
              const Color(0xFF0D9488),
              isDark,
            ),
          ],
          if (_engineFilter == 'Yandex' ||
              (kw.yandexAveragePosition != null &&
                  kw.yandexAveragePosition! > 0)) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildEngineSubRow(
              'Yandex Webmaster Average Position',
              kw.yandexAveragePosition,
              kw.yandexClicks,
              kw.yandexImpressions,
              kw.yandexRankingUrl,
              const Color(0xFFEA580C),
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineSubRow(
    String label,
    double? avgPos,
    int clicks,
    int impressions,
    String? url,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.travel_explore, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (avgPos != null && avgPos > 0) ...[
                  Text(
                    'Avg #${avgPos.toStringAsFixed(1)} • $clicks clicks • $impressions impr.',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ] else ...[
                  Text(
                    'No data available',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
