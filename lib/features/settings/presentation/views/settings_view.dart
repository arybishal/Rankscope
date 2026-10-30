import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rankscope/core/logging/app_logger.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/backup_restore/data/services/backup_restore_service.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:share_plus/share_plus.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return BackupRestoreService();
});

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _bingKeyController = TextEditingController();
  final _gscClientController = TextEditingController();
  bool _isLoadingKeys = true;
  DateTime? _lastBackupDate;
  int _logErrorCount = 0;
  int _totalLogCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
    _loadLogStats();
  }

  Future<void> _loadLogStats() async {
    final stats = await AppLogger.instance.getLogStats();
    if (mounted) {
      setState(() {
        _totalLogCount = stats['total'] as int? ?? 0;
        _logErrorCount = stats['errors'] as int? ?? 0;
      });
    }
  }

  Future<void> _loadStoredCredentials() async {
    final storage = ref.read(secureStorageServiceProvider);
    final bingKey = await storage.getBingApiKey();
    final gscClient = await storage.getGscClientId();

    if (mounted) {
      setState(() {
        _bingKeyController.text = bingKey ?? '';
        _gscClientController.text = gscClient ?? '';
        _isLoadingKeys = false;
      });
    }
  }

  @override
  void dispose() {
    _bingKeyController.dispose();
    _gscClientController.dispose();
    super.dispose();
  }

  Future<void> _saveBingKey() async {
    final storage = ref.read(secureStorageServiceProvider);
    final key = _bingKeyController.text.trim();
    if (key.isNotEmpty) {
      await storage.saveBingApiKey(key);
      await AppLogger.instance.info(
        'Settings',
        'bing_key_saved',
        'Saved Bing API key in Android KeyStore',
      );
    } else {
      await storage.clearBingCredentials();
      await AppLogger.instance.info(
        'Settings',
        'bing_key_cleared',
        'Cleared Bing API key',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bing API credentials saved to Android KeyStore.'),
        ),
      );
    }
  }

  Future<void> _saveGscClientId() async {
    final storage = ref.read(secureStorageServiceProvider);
    final id = _gscClientController.text.trim();
    if (id.isNotEmpty) {
      await storage.saveGscClientId(id);
      await AppLogger.instance.info(
        'Settings',
        'gsc_client_id_saved',
        'Saved Google OAuth Client ID',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google OAuth Client ID saved.')),
      );
    }
  }

  // --- Complete Encrypted Export Backup Flow ---

  Future<void> _showExportBackupDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: const Text(
            'Export Complete Backup',
            style: AppTextStyles.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your backup will be encrypted with AES-256-GCM. All websites, keywords, ranking history, and credentials are included.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.rankGain,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Important: Losing this password means the backup cannot be restored.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Backup Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: confirmController,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final pwd = passwordController.text;
                if (pwd.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a password.')),
                  );
                  return;
                }
                if (pwd != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Export & Encrypt'),
            ),
          ],
        ),
      ),
    );

    if (shouldExport == true) {
      final password = passwordController.text;
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encrypting complete backup...')),
        );

        final service = ref.read(backupRestoreServiceProvider);
        final file = await service.exportEncryptedBackup(password: password);

        setState(() {
          _lastBackupDate = DateTime.now();
        });

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'RankScope Encrypted Backup (AES-256-GCM)',
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppColors.rankDrop,
            ),
          );
        }
      }
    }
  }

  // --- Complete Encrypted Import Backup Flow ---

  Future<void> _startImportBackup() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isEmpty || files.first.path == null) return;
      final filePath = files.first.path!;

      if (!mounted) return;

      // Ask for backup password
      final passwordController = TextEditingController();
      bool obscure = true;

      final enteredPassword = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surfacePrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            title: const Text(
              'Unlock Backup Archive',
              style: AppTextStyles.titleLarge,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the password used when exporting this .rankscope file to decrypt and verify integrity.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Backup Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(passwordController.text),
                child: const Text('Verify & Preview'),
              ),
            ],
          ),
        ),
      );

      if (enteredPassword == null || enteredPassword.isEmpty) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Decrypting and verifying backup integrity...'),
        ),
      );

      final service = ref.read(backupRestoreServiceProvider);
      final preview = await service.inspectAndDecryptBackup(
        filePath: filePath,
        password: enteredPassword,
      );

      if (!mounted) return;

      // Show preview & import mode selector
      await _showRestoreModeDialog(preview);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: AppColors.rankDrop,
          ),
        );
      }
    }
  }

  Future<void> _showRestoreModeDialog(Map<String, dynamic> preview) async {
    final payload = preview['payload'] as Map<String, dynamic>;
    final exportDateStr = preview['exported_at']?.toString() ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Backup Verified', style: AppTextStyles.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Created: $exportDateStr', style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: AppSpacing.xs),
              const Text('Archive Contents:', style: AppTextStyles.labelLarge),
              const SizedBox(height: 6),
              _previewRow(
                Icons.language,
                'Websites',
                '${preview['websites_count']}',
              ),
              _previewRow(
                Icons.search,
                'Keywords',
                '${preview['keywords_count']}',
              ),
              _previewRow(
                Icons.timeline,
                'Ranking Records',
                '${preview['ranking_records_count']}',
              ),
              _previewRow(
                Icons.key,
                'Stored Integrations',
                '${preview['integrations_count']}',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Select Restoration Mode:',
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: 8),
              _RestoreModeOption(
                icon: Icons.restore_page_outlined,
                title: 'Full Restore (Replace All)',
                description: 'Overwrites live database with backup data. An automatic recovery snapshot is saved before replacement.',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _executeFullRestore(payload);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _RestoreModeOption(
                icon: Icons.merge_type,
                title: 'Merge Import (Safe Non-Destructive)',
                description: 'Adds imported websites and keywords without deleting existing data or creating duplicate domains.',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _executeMergeImport(payload);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Text(value, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }

  Future<void> _executeFullRestore(Map<String, dynamic> payload) async {
    try {
      final service = ref.read(backupRestoreServiceProvider);
      await service.performFullRestore(payload);
      await ref.read(websitesProvider.notifier).loadWebsites();
      await _loadStoredCredentials();
      await _loadLogStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Full restore completed successfully. All data and credentials restored.',
            ),
            backgroundColor: AppColors.rankGain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Full restore failed: $e'),
            backgroundColor: AppColors.rankDrop,
          ),
        );
      }
    }
  }

  Future<void> _executeMergeImport(Map<String, dynamic> payload) async {
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final stats = await service.performMergeImport(payload);
      await ref.read(websitesProvider.notifier).loadWebsites();
      await _loadStoredCredentials();
      await _loadLogStats();

      if (mounted) {
        final sitesAdded = stats['websites_added'] ?? 0;
        final kwsAdded = stats['keywords_added'] ?? 0;
        final ranksAdded = stats['rankings_added'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Merged successfully: $sitesAdded websites, $kwsAdded keywords, $ranksAdded ranking records added.',
            ),
            backgroundColor: AppColors.rankGain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: $e'),
            backgroundColor: AppColors.rankDrop,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text(
          'Settings & Privacy',
          style: AppTextStyles.titleLarge,
        ),
      ),
      body: _isLoadingKeys
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Air-Gapped Encrypted Backup & Restore
                const Text(
                  'DATA PERSISTENCE & BACKUP',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_reset,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'AES-256-GCM Encrypted Backups',
                            style: AppTextStyles.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Export a portable .rankscope archive containing all websites, keywords, ranking history, and securely encrypted API credentials. Protected by PBKDF2 authenticated encryption.',
                        style: AppTextStyles.bodySmall,
                      ),
                      if (_lastBackupDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last exported: ${DateFormat('yyyy-MM-dd HH:mm').format(_lastBackupDate!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.file_upload_outlined,
                                size: 16,
                              ),
                              label: const Text('Export Backup'),
                              onPressed: _showExportBackupDialog,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.file_download_outlined,
                                size: 16,
                              ),
                              label: const Text('Import Backup'),
                              onPressed: _startImportBackup,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Logs & Diagnostics Section
                const Text(
                  'DEVELOPMENT & TROUBLESHOOTING',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () async {
                    await context.push('/logs');
                    _loadLogStats();
                  },
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.terminal,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Logs & Diagnostics Center',
                                style: AppTextStyles.labelLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'View local audit logs, search events, export reports, and debug issues.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '$_totalLogCount entries',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  if (_logErrorCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.rankDrop.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$_logErrorCount errors',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.rankDrop,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bing API Integration
                const Text(
                  'BING WEBMASTER TOOLS (OPTIONAL)',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bing Free API Key',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Generate a free API key from your Bing Webmaster Tools portal (Settings > API Access). Stored securely in Android KeyStore.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _bingKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Paste Bing API Key here...',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: _saveBingKey,
                        child: const Text('Save Bing Key'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Google Search Console OAuth
                const Text(
                  'GOOGLE SEARCH CONSOLE (OPTIONAL)',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Google Cloud OAuth Client ID',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Uses serverless OAuth 2.0 PKCE directly from your Android phone to Google. Zero intermediate server.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _gscClientController,
                        decoration: const InputDecoration(
                          hintText: 'your-client-id.apps.googleusercontent.com',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: _saveGscClientId,
                        child: const Text('Save Client ID'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Privacy Manifesto Summary
                const Text(
                  'DATA SOVEREIGNTY & PRIVACY',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: AppColors.rankGain,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '100% Device-Only Privacy',
                            style: AppTextStyles.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Zero backend servers or cloud databases\n'
                        '• Zero telemetry, analytics, or crash tracking SDKs\n'
                        '• Zero Google/Bing web scraping or ToS violations\n'
                        '• Strictly \$0 budget forever\n'
                        '• All records live in your device SQLite database',
                        style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RestoreModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RestoreModeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelMedium),
                  const SizedBox(height: 2),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
