import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rankscope/core/logging/app_logger.dart';
import 'package:rankscope/core/logging/log_entry.dart';
import 'package:rankscope/core/logging/log_level.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:share_plus/share_plus.dart';

/// Central Logs & Diagnostics Dashboard for troubleshooting and auditing.
class LogsView extends StatefulWidget {
  const LogsView({super.key});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final _searchController = TextEditingController();
  final _logger = AppLogger.instance;

  LogLevel? _selectedLevel;
  String _selectedModule = 'ALL';
  List<LogEntry> _logs = [];
  Map<String, dynamic> _stats = {'total': 0, 'errors': 0, 'warnings': 0};
  bool _isLoading = true;

  final List<String> _modules = [
    'ALL',
    'Database',
    'Websites',
    'Keywords',
    'Backup',
    'GSC',
    'Bing',
    'UI',
    'Security',
    'App',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final stats = await _logger.getLogStats();
    final logs = await _logger.getLogs(
      level: _selectedLevel,
      module: _selectedModule,
      searchQuery: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _stats = stats;
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _copyAllLogs() async {
    final text = await _logger.exportAsTextString(_logs);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${_logs.length} log entries to clipboard.'),
        ),
      );
    }
  }

  Future<void> _exportTxt() async {
    try {
      final file = await _logger.exportToTextFile();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'RankScope Diagnostic Logs (.txt)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export TXT logs: $e')),
        );
      }
    }
  }

  Future<void> _exportJson() async {
    try {
      final file = await _logger.exportToJsonFile();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'RankScope Diagnostic Logs (.json)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export JSON logs: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearLogs() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          'Clear All Diagnostic Logs',
          style: AppTextStyles.titleLarge,
        ),
        content: const Text(
          'Are you sure you want to delete all stored diagnostic logs? This action cannot be undone.',
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
              await _logger.clearLogs();
              await _loadLogs();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostic logs cleared.')),
                );
              }
            },
            child: const Text(
              'Clear Logs',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return AppColors.textTertiary;
      case LogLevel.info:
        return const Color(0xFF2563EB); // Royal Blue
      case LogLevel.warning:
        return const Color(0xFFD97706); // Amber
      case LogLevel.error:
        return AppColors.rankDrop; // Crimson
      case LogLevel.critical:
        return const Color(0xFF991B1B); // Deep Dark Red
    }
  }

  void _showLogDetails(LogEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getLevelColor(entry.level).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getLevelColor(entry.level).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                entry.level.label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: _getLevelColor(entry.level),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.eventName,
                style: AppTextStyles.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(entry.timestamp)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Module: ${entry.module}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: AppSpacing.xs),
              const Text('Message', style: AppTextStyles.labelLarge),
              const SizedBox(height: 4),
              SelectableText(entry.message, style: AppTextStyles.bodyMedium),
              if (entry.details != null && entry.details!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Technical Details / StackTrace',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: SelectableText(
                    entry.details!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Log'),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: entry.toFormattedString()),
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Log entry copied to clipboard.'),
                  ),
                );
              }
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd HH:mm:ss');

    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text(
          'Logs & Diagnostics',
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            tooltip: 'Refresh Logs',
            onPressed: _loadLogs,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (val) {
              if (val == 'copy_all') _copyAllLogs();
              if (val == 'export_txt') _exportTxt();
              if (val == 'export_json') _exportJson();
              if (val == 'clear') _confirmClearLogs();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'copy_all',
                child: Row(
                  children: [
                    Icon(Icons.copy_all, size: 18),
                    SizedBox(width: 8),
                    Text('Copy All Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_txt',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Export as .txt'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 18),
                    SizedBox(width: 8),
                    Text('Export as .json'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.rankDrop,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear Logs',
                      style: TextStyle(color: AppColors.rankDrop),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Metrics Cards Row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Logs',
                    value: '${_stats['total'] ?? 0}',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: 'Errors',
                    value: '${_stats['errors'] ?? 0}',
                    color: (_stats['errors'] ?? 0) > 0
                        ? AppColors.rankDrop
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: 'Warnings',
                    value: '${_stats['warnings'] ?? 0}',
                    color: (_stats['warnings'] ?? 0) > 0
                        ? const Color(0xFFD97706)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search logs by event, module, or text...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadLogs();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
              ),
              onSubmitted: (_) => _loadLogs(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Filters Row (Level & Module)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            child: Row(
              children: [
                // Level Dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LogLevel?>(
                        value: _selectedLevel,
                        isExpanded: true,
                        hint: const Text(
                          'All Levels',
                          style: AppTextStyles.bodySmall,
                        ),
                        items: [
                          const DropdownMenuItem<LogLevel?>(
                            value: null,
                            child: Text(
                              'All Levels',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                          ...LogLevel.values.map(
                            (lvl) => DropdownMenuItem<LogLevel?>(
                              value: lvl,
                              child: Text(
                                lvl.label,
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (lvl) {
                          setState(() => _selectedLevel = lvl);
                          _loadLogs();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Module Dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedModule,
                        isExpanded: true,
                        items: _modules.map((m) {
                          return DropdownMenuItem<String>(
                            value: m,
                            child: Text(
                              m == 'ALL' ? 'All Modules' : m,
                              style: AppTextStyles.bodySmall,
                            ),
                          );
                        }).toList(),
                        onChanged: (m) {
                          if (m != null) {
                            setState(() => _selectedModule = m);
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Logs List View
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_toggle_off,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No Diagnostic Logs Found',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Events will appear here as the application runs.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _logs.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final color = _getLevelColor(log.level);

                      return InkWell(
                        onTap: () => _showLogDetails(log),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.level.label,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '[${log.module}] ${log.eventName}',
                                          style: AppTextStyles.labelMedium,
                                        ),
                                        const Spacer(),
                                        Text(
                                          dateFormat.format(log.timestamp),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      log.message,
                                      style: AppTextStyles.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (log.details != null &&
                                  log.details!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
