import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/surfaces/glass_container.dart';
import '../controllers/sync_controller.dart';
import '../../domain/models/sync_models.dart';

/// Interactive Dashboard Card providing Auto Sync controls, Next/Last sync timestamps,
/// a prominent "Sync All Now" button, live progress, and detailed status breakdowns.
class SyncDashboardCard extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsPressed;

  const SyncDashboardCard({super.key, this.onSettingsPressed});

  @override
  ConsumerState<SyncDashboardCard> createState() => _SyncDashboardCardState();
}

class _SyncDashboardCardState extends ConsumerState<SyncDashboardCard> {
  bool _showDetails = false;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day + 1;

    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) return 'Today at $timeStr';
    if (isTomorrow) return 'Tomorrow at $timeStr';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncState = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    final summary = syncState.lastSummary;
    final isSyncing = syncState.isSyncing;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Title + Auto Sync Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF60A5FA) : AppColors.accent)
                            .withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sync,
                        size: 20,
                        color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Engine Sync Dashboard',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Unified GSC, Bing & Yandex background sync',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    syncState.autoSyncEnabled ? 'Auto ON' : 'Auto OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: syncState.autoSyncEnabled
                          ? AppColors.rankGain
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch.adaptive(
                    value: syncState.autoSyncEnabled,
                    activeTrackColor: AppColors.accent,
                    onChanged: (val) {
                      controller.toggleAutoSync(val);
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. Schedule & Last Sync Badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.black.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 15,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next Scheduled',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            Text(
                              syncState.autoSyncEnabled
                                  ? _formatDateTime(syncState.nextScheduledSync)
                                  : 'Disabled',
                              style: AppTextStyles.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
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
                Container(
                  width: 1,
                  height: 24,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: summary?.isSuccess == true ? AppColors.rankGain : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Sync',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            Text(
                              _formatDateTime(syncState.lastSyncTime),
                              style: AppTextStyles.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
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
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 3. Prominent "Sync All Now" Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              icon: isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync, size: 20),
              label: Text(
                isSyncing ? 'Syncing All Websites...' : 'Sync All Now',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: isSyncing
                  ? null
                  : () async {
                      try {
                        final res = await controller.syncAllNow();
                        if (res != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.overallMessage),
                              backgroundColor: res.hasFailures
                                  ? AppColors.rankDrop
                                  : AppColors.rankGain,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sync failed: $e'),
                              backgroundColor: AppColors.rankDrop,
                            ),
                          );
                        }
                      }
                    },
            ),
          ),

          // 4. Live Progress indicator during Sync
          if (isSyncing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: syncState.progress.percent > 0 ? syncState.progress.percent : null,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    syncState.progress.currentOperation,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (syncState.progress.totalSteps > 0)
                  Text(
                    '${(syncState.progress.percent * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // 5. Sync Metrics Grid (Total Websites, Success, Failed, Status)
          Row(
            children: [
              _buildStatBox(
                context,
                title: 'Websites',
                value: '${summary?.totalWebsites ?? syncState.totalWebsitesCount}',
                icon: Icons.language,
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatBox(
                context,
                title: 'Successful',
                value: '${summary?.successfulWebsites ?? 0}',
                icon: Icons.check_circle_outline,
                color: AppColors.rankGain,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatBox(
                context,
                title: 'Failed',
                value: '${summary?.failedWebsites ?? 0}',
                icon: Icons.error_outline,
                color: (summary?.failedWebsites ?? 0) > 0
                    ? AppColors.rankDrop
                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatBox(
                context,
                title: 'Status',
                value: isSyncing
                    ? 'Running'
                    : (summary?.status.replaceAll('_', ' ').toUpperCase() ?? 'IDLE'),
                icon: Icons.info_outline,
                color: isSyncing
                    ? Colors.amber
                    : (summary?.isSuccess == true ? AppColors.rankGain : Colors.grey),
                isDark: isDark,
                isTextSmall: true,
              ),
            ],
          ),

          // 6. Source Breakdown Badges (Google, Bing, Yandex)
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildSourceBadge(
                name: 'Google',
                queries: summary?.googleQueries ?? 0,
                isDark: isDark,
              ),
              _buildSourceBadge(
                name: 'Bing',
                queries: summary?.bingQueries ?? 0,
                isDark: isDark,
              ),
              _buildSourceBadge(
                name: 'Yandex',
                queries: summary?.yandexQueries ?? 0,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // 7. Actions: Toggle Website Breakdown & View History Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (summary != null && summary.websiteDetails.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() => _showDetails = !_showDetails);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      children: [
                        Text(
                          _showDetails ? 'Hide Site Details' : 'Site Breakdown',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                          ),
                        ),
                        Icon(
                          _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 14,
                          color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  context.push('/sync-history');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 14,
                        color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Audit History Log',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_showDetails && summary != null) ...[
            const SizedBox(height: 6),
            ...summary.websiteDetails.map((site) => _buildSiteDetailRow(site, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isTextSmall = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: isTextSmall ? 10 : 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge({
    required String name,
    required int queries,
    required bool isDark,
  }) {
    final color = name == 'Google'
        ? Colors.blue
        : (name == 'Bing' ? Colors.teal : Colors.deepOrange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$name: $queries queries',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteDetailRow(WebsiteSyncDetail site, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black.withAlpha(6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            site.isSuccess ? Icons.check_circle : Icons.error,
            size: 14,
            color: site.isSuccess ? AppColors.rankGain : AppColors.rankDrop,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.domain,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  site.isSuccess
                      ? '${site.matchedKeywords} matched kw • ${site.engineDetails.map((e) => "${e.engine}: ${e.queriesCount}").join(", ")}'
                      : (site.errorMessage ?? 'Sync failed'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
