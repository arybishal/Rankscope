import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/feedback/empty_state_view.dart';
import '../../../../shared/widgets/surfaces/glass_container.dart';
import '../controllers/sync_controller.dart';
import '../../data/datasources/sync_history_datasource.dart';

final syncHistoryDatasourceProvider = Provider<SyncHistoryDatasource>((ref) {
  return SyncHistoryDatasource();
});

final syncHistoryListProvider =
    FutureProvider.autoDispose.family<List<SyncHistoryRecord>, int?>((ref, websiteId) async {
  final ds = ref.watch(syncHistoryDatasourceProvider);
  return await ds.getRecentRecords(websiteId: websiteId, limit: 100);
});

/// Dedicated screen displaying the complete persistent sync history audit log.
class SyncHistoryView extends ConsumerStatefulWidget {
  final int? initialWebsiteId;

  const SyncHistoryView({super.key, this.initialWebsiteId});

  @override
  ConsumerState<SyncHistoryView> createState() => _SyncHistoryViewState();
}

class _SyncHistoryViewState extends ConsumerState<SyncHistoryView> {
  String _selectedEngine = 'All'; // 'All', 'Google', 'Bing', 'Yandex'

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return 'Today, ${DateFormat('h:mm:ss a').format(dt)}';
    }
    return DateFormat('MMM d, h:mm:ss a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncState = ref.watch(syncControllerProvider);
    final historyAsync = ref.watch(syncHistoryListProvider(widget.initialWebsiteId));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Sync Audit History', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Log',
            onPressed: () {
              ref.invalidate(syncHistoryListProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear History',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Sync History'),
                  content: const Text(
                    'Are you sure you want to clear all sync history audit records? This does not delete keywords or ranking data.',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rankDrop,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Clear All'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(syncHistoryDatasourceProvider).clearHistory();
                ref.invalidate(syncHistoryListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync history log cleared.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Status Overview Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Successful',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          syncState.lastSyncTime != null
                              ? DateFormat('MMM d, h:mm a').format(syncState.lastSyncTime!)
                              : 'None',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.withAlpha(50)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next Scheduled',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          syncState.autoSyncEnabled && syncState.nextScheduledSync != null
                              ? DateFormat('MMM d, h:mm a').format(syncState.nextScheduledSync!)
                              : 'Disabled',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Engine Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            child: Row(
              children: ['All', 'Google', 'Bing', 'Yandex'].map((eng) {
                final isSelected = _selectedEngine == eng;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(eng, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: (isDark ? const Color(0xFF2563EB) : AppColors.accent)
                        .withAlpha(40),
                    checkmarkColor: AppColors.accent,
                    onSelected: (val) {
                      setState(() => _selectedEngine = eng);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 3. History List
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (err, _) => Center(
                child: Text('Error loading history: $err'),
              ),
              data: (records) {
                final filtered = _selectedEngine == 'All'
                    ? records
                    : records
                        .where((r) =>
                            r.searchEngine.toLowerCase() == _selectedEngine.toLowerCase())
                        .toList();

                if (filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.history,
                    title: 'No Sync History',
                    description:
                        'Sync records will appear here automatically when manual or daily background sync executes.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildHistoryCard(item, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(SyncHistoryRecord item, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case 'success':
        statusColor = AppColors.rankGain;
        statusIcon = Icons.check_circle;
        break;
      case 'partial_success':
        statusColor = Colors.amber;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'failed':
        statusColor = AppColors.rankDrop;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    final durationSec = item.duration.inMilliseconds / 1000.0;
    final engineColor = item.searchEngine == 'Google'
        ? Colors.blue
        : (item.searchEngine == 'Bing' ? Colors.teal : Colors.deepOrange);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.websiteDomain,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: engineColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.searchEngine,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: engineColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (item.triggerType == 'auto' ? Colors.purple : Colors.indigo)
                      .withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.triggerType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: item.triggerType == 'auto' ? Colors.purple : Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTimestamp(item.completedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              Text(
                '${durationSec.toStringAsFixed(1)}s • ${item.recordsRetrieved} queries • ${item.matchedKeywords} matched',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (item.errorDetails != null && item.errorDetails!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.rankDrop.withAlpha(15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.errorDetails!,
                style: const TextStyle(fontSize: 10, color: AppColors.rankDrop),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
