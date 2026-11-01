import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rankscope/core/constants/api_documentation_urls.dart';
import 'package:rankscope/core/logging/app_logger.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/core/theme/theme_controller.dart';
import 'package:rankscope/features/backup_restore/data/services/backup_restore_service.dart';
import 'package:rankscope/features/bing_webmaster/presentation/controllers/bing_controller.dart';
import 'package:rankscope/features/dashboard/presentation/controllers/dashboard_trend_controller.dart';
import 'package:rankscope/features/dashboard/presentation/views/dashboard_view.dart'
    hide yandexConfiguredProvider;
import 'package:rankscope/features/keywords/presentation/controllers/keywords_controller.dart';
import 'package:rankscope/features/search_console/presentation/controllers/gsc_controller.dart';
import 'package:rankscope/features/websites/presentation/controllers/websites_controller.dart';
import 'package:rankscope/features/yandex_webmaster/presentation/controllers/yandex_controller.dart';
import 'package:rankscope/features/sync/presentation/controllers/sync_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _gscServerClientController = TextEditingController();
  final _gscAccessTokenController = TextEditingController();
  final _gscRefreshTokenController = TextEditingController();
  final _yandexTokenController = TextEditingController();
  bool _isLoadingKeys = true;
  bool _isTestingBingKey = false;
  bool _isTestingGscToken = false;
  bool _isSigningInGoogle = false;
  bool _isTestingYandexToken = false;
  bool _showAdvancedGsc = false;
  String? _gscUserEmail;
  List<String> _gscVerifiedSites = [];
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
    final gscServerClient = await storage.getGscServerClientId();
    final gscAccess = await storage.getGscAccessToken();
    final gscRefresh = await storage.getGscRefreshToken();
    final gscEmail = await storage.getGscUserEmail();
    final yandexToken = await storage.getYandexOAuthToken();

    if (mounted) {
      setState(() {
        _bingKeyController.text = bingKey ?? '';
        _gscClientController.text = gscClient ?? '';
        _gscServerClientController.text = gscServerClient ?? '';
        _gscAccessTokenController.text = gscAccess ?? '';
        _gscRefreshTokenController.text = gscRefresh ?? '';
        _gscUserEmail = gscEmail;
        _yandexTokenController.text = yandexToken ?? '';
        _isLoadingKeys = false;
      });
    }
  }

  @override
  void dispose() {
    _bingKeyController.dispose();
    _gscClientController.dispose();
    _gscServerClientController.dispose();
    _gscAccessTokenController.dispose();
    _gscRefreshTokenController.dispose();
    _yandexTokenController.dispose();
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

  Future<void> _testBingConnection() async {
    setState(() => _isTestingBingKey = true);
    final key = _bingKeyController.text.trim();
    if (key.isNotEmpty) {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveBingApiKey(key);
    }

    final sites = await ref
        .read(bingSyncNotifierProvider.notifier)
        .testConnection();
    if (!mounted) return;
    setState(() => _isTestingBingKey = false);

    if (sites != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sites.isNotEmpty
                ? 'Bing API connected! Found ${sites.length} verified site(s).'
                : 'Bing API connected, but no verified sites found on this account.',
          ),
          backgroundColor: AppColors.rankGain,
        ),
      );
    } else {
      final error =
          ref.read(bingSyncNotifierProvider).errorMessage ??
          'Connection failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.rankDrop),
      );
    }
  }

  Future<void> _saveGscCredentials() async {
    final storage = ref.read(secureStorageServiceProvider);
    final androidId = _gscClientController.text.trim();
    final webId = _gscServerClientController.text.trim();
    final token = _gscAccessTokenController.text.trim();
    final refresh = _gscRefreshTokenController.text.trim();

    if (androidId.isNotEmpty) {
      await storage.saveGscClientId(androidId);
    } else {
      await storage.clearGscClientId();
    }

    if (webId.isNotEmpty) {
      await storage.saveGscServerClientId(webId);
    } else {
      await storage.clearGscServerClientId();
    }

    if (token.isNotEmpty) {
      await storage.saveGscAccessToken(token);
    }
    if (refresh.isNotEmpty) {
      await storage.saveGscRefreshToken(refresh);
    }

    if (androidId.isEmpty && webId.isEmpty && token.isEmpty && refresh.isEmpty) {
      await storage.clearGscCredentials();
    }

    ref.invalidate(googleConfiguredProvider);
    await AppLogger.instance.info(
      'Settings',
      'gsc_credentials_saved',
      'Updated Google Search Console credentials in Android KeyStore',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Search Console credentials saved to Android KeyStore.'),
        ),
      );
    }
  }

  Future<void> _connectWithGoogle() async {
    setState(() => _isSigningInGoogle = true);
    try {
      final androidId = _gscClientController.text.trim();
      final webId = _gscServerClientController.text.trim();
      final status = await ref
          .read(gscConnectionStatusProvider.notifier)
          .connectGoogle(
            clientId: androidId.isNotEmpty ? androidId : null,
            serverClientId: webId.isNotEmpty ? webId : null,
          );

      await _loadStoredCredentials();

      if (!mounted) return;
      setState(() {
        _isSigningInGoogle = false;
        if (status.verifiedSites.isNotEmpty) {
          _gscVerifiedSites = status.verifiedSites;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isConnected
                ? 'Google account connected! Found ${status.verifiedSites.length} property(ies).'
                : status.message,
          ),
          backgroundColor:
              status.isConnected ? AppColors.rankGain : AppColors.rankDrop,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningInGoogle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect Google account: $e'),
          backgroundColor: AppColors.rankDrop,
        ),
      );
    }
  }

  Future<void> _disconnectGoogle() async {
    await ref.read(gscConnectionStatusProvider.notifier).disconnect();
    await _loadStoredCredentials();
    if (!mounted) return;
    setState(() {
      _gscVerifiedSites = [];
      _gscAccessTokenController.clear();
      _gscRefreshTokenController.clear();
      _gscUserEmail = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google account disconnected.')),
    );
  }

  Future<void> _testGscConnection() async {
    setState(() => _isTestingGscToken = true);
    final storage = ref.read(secureStorageServiceProvider);
    final androidId = _gscClientController.text.trim();
    final webId = _gscServerClientController.text.trim();
    final token = _gscAccessTokenController.text.trim();
    final refresh = _gscRefreshTokenController.text.trim();

    if (androidId.isNotEmpty) await storage.saveGscClientId(androidId);
    if (webId.isNotEmpty) await storage.saveGscServerClientId(webId);
    if (token.isNotEmpty) await storage.saveGscAccessToken(token);
    if (refresh.isNotEmpty) await storage.saveGscRefreshToken(refresh);

    final sites = await ref.read(gscSyncNotifierProvider.notifier).testConnection();
    if (!mounted) return;
    setState(() {
      _isTestingGscToken = false;
      if (sites != null) {
        _gscVerifiedSites = sites;
      }
    });

    if (sites != null) {
      ref.invalidate(googleConfiguredProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sites.isNotEmpty
                ? 'Google Search Console connected! Found ${sites.length} verified site(s).'
                : 'Google Search Console connected, but no verified properties found on this account.',
          ),
          backgroundColor: AppColors.rankGain,
        ),
      );
    } else {
      final error = ref.read(gscSyncNotifierProvider).errorMessage ?? 'Connection failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.rankDrop,
        ),
      );
    }
  }

  Future<void> _saveYandexToken() async {
    final storage = ref.read(secureStorageServiceProvider);
    final token = _yandexTokenController.text.trim();
    if (token.isNotEmpty) {
      await storage.saveYandexOAuthToken(token);
      await AppLogger.instance.info(
        'Settings',
        'yandex_token_saved',
        'Saved Yandex OAuth token in Android KeyStore',
      );
    } else {
      await storage.clearYandexCredentials();
      await AppLogger.instance.info(
        'Settings',
        'yandex_token_cleared',
        'Cleared Yandex OAuth token',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yandex OAuth token saved to Android KeyStore.'),
        ),
      );
    }
  }

  Future<void> _testYandexConnection() async {
    setState(() => _isTestingYandexToken = true);
    final token = _yandexTokenController.text.trim();
    if (token.isNotEmpty) {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveYandexOAuthToken(token);
    }

    final hosts = await ref
        .read(yandexSyncNotifierProvider.notifier)
        .testConnection();
    if (!mounted) return;
    setState(() => _isTestingYandexToken = false);

    if (hosts != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hosts.isNotEmpty
                ? 'Yandex API connected! Found ${hosts.length} verified host(s).'
                : 'Yandex API connected, but no verified hosts found on this account.',
          ),
          backgroundColor: AppColors.rankGain,
        ),
      );
    } else {
      final error =
          ref.read(yandexSyncNotifierProvider).errorMessage ??
          'Connection failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.rankDrop),
      );
    }
  }

  // --- Complete Encrypted Export Backup Flow ---

  Future<void> _showExportBackupDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    bool includeCredentials = true;

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
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: includeCredentials,
                  onChanged: (val) {
                    setDialogState(() => includeCredentials = val ?? true);
                  },
                  title: const Text(
                    'Include API credentials & OAuth tokens',
                    style: AppTextStyles.labelMedium,
                  ),
                  subtitle: const Text(
                    'Credentials will be encrypted within the backup archive',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
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
        final file = await service.exportEncryptedBackup(
          password: password,
          includeCredentials: includeCredentials,
        );

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
                description:
                    'Overwrites live database with backup data. An automatic recovery snapshot is saved before replacement.',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (alertCtx) => AlertDialog(
                      backgroundColor: AppColors.surfacePrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        side: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      title: const Text(
                        'Confirm Full Replacement',
                        style: AppTextStyles.titleLarge,
                      ),
                      content: const Text(
                        'Warning: This action will replace all current websites, keywords, and tracking history with the records from the backup archive.\n\nAn automatic recovery snapshot will be saved on device before replacement.\n\nAre you sure you want to proceed?',
                        style: AppTextStyles.bodyMedium,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(alertCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rankDrop,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(alertCtx).pop(true),
                          child: const Text('Replace All Data'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _executeFullRestore(payload);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _RestoreModeOption(
                icon: Icons.merge_type,
                title: 'Merge Import (Safe Non-Destructive)',
                description:
                    'Adds imported websites and keywords without deleting existing data or creating duplicate domains.',
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
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }

  Future<void> _executeFullRestore(Map<String, dynamic> payload) async {
    try {
      final service = ref.read(backupRestoreServiceProvider);
      await service.performFullRestore(payload);

      // Reload database records into Riverpod state
      final sites = await ref.read(websitesRepositoryProvider).getWebsites();
      await ref.read(websitesProvider.notifier).loadWebsites();
      if (sites.isNotEmpty) {
        ref.read(selectedWebsiteIdProvider.notifier).select(sites.first.id);
      }

      // Invalidate all downstream cached Riverpod family and future providers
      ref.invalidate(keywordsFamilyProvider);
      ref.invalidate(dashboardTrendProvider);
      ref.invalidate(cannibalizationAlertsFamilyProvider);
      ref.invalidate(googleConfiguredProvider);
      ref.invalidate(bingConfiguredProvider);
      ref.invalidate(yandexConfiguredProvider);

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

      // Reload database records into Riverpod state
      final sites = await ref.read(websitesRepositoryProvider).getWebsites();
      await ref.read(websitesProvider.notifier).loadWebsites();
      if (sites.isNotEmpty && ref.read(selectedWebsiteIdProvider) == null) {
        ref.read(selectedWebsiteIdProvider.notifier).select(sites.first.id);
      }

      // Invalidate all downstream cached Riverpod family and future providers
      ref.invalidate(keywordsFamilyProvider);
      ref.invalidate(dashboardTrendProvider);
      ref.invalidate(cannibalizationAlertsFamilyProvider);
      ref.invalidate(googleConfiguredProvider);
      ref.invalidate(bingConfiguredProvider);
      ref.invalidate(yandexConfiguredProvider);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfacePrimary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final secondaryBg =
        isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surfacePrimary,
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
                // Theme & Appearance
                const Text(
                  'APPEARANCE & THEME',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Display Mode',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Choose between light, dark, or system default theme.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto, size: 16),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode, size: 16),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode, size: 16),
                          ),
                        ],
                        selected: {currentThemeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(newSelection.first);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Manage Websites
                const Text(
                  'WEBSITES & PROPERTIES',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsNavCard(
                  icon: Icons.language_outlined,
                  title: 'Manage Tracked Websites',
                  description: 'Add new websites, configure competitors, view Bing verification status, and switch active properties.',
                  onTap: () => context.push('/websites'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsNavCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'App Feature Tour',
                  description: 'Replay the interactive feature showcase and discover everything RankScope can do.',
                  onTap: () => context.push('/onboarding?revisit=true'),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Air-Gapped Encrypted Backup & Restore
                const Text(
                  'DATA PERSISTENCE & BACKUP',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: borderColor),
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
                      color: cardBg,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: secondaryBg,
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

                // Automatic & Background Sync
                const Text(
                  'AUTOMATIC & BACKGROUND SYNC',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Consumer(
                  builder: (context, ref, _) {
                    final syncState = ref.watch(syncControllerProvider);
                    final syncCtrl = ref.read(syncControllerProvider.notifier);
                    final timeStr = DateFormat('h:mm a').format(
                      DateTime(2026, 1, 1, syncState.autoSyncHour, syncState.autoSyncMinute),
                    );

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.sync,
                                  size: 18,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Daily Scheduled Sync',
                                  style: AppTextStyles.labelLarge,
                                ),
                              ),
                              Switch.adaptive(
                                value: syncState.autoSyncEnabled,
                                activeTrackColor: AppColors.accent,
                                onChanged: (val) => syncCtrl.toggleAutoSync(val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Automatically queries all active websites and connected engines (Google, Bing, Yandex) once daily using Android WorkManager.',
                            style: AppTextStyles.bodySmall,
                          ),
                          if (syncState.autoSyncEnabled) ...[
                            const SizedBox(height: AppSpacing.md),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.md),

                            // Configurable Sync Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Sync Time (Local Time)', style: AppTextStyles.labelMedium),
                                      Text(
                                        'Device timezone: ${DateTime.now().timeZoneName}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(timeStr),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(
                                        hour: syncState.autoSyncHour,
                                        minute: syncState.autoSyncMinute,
                                      ),
                                    );
                                    if (picked != null) {
                                      await syncCtrl.updateScheduleTime(picked.hour, picked.minute);
                                    }
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // Configurable Date Window
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Historical Date Window', style: AppTextStyles.labelMedium),
                                      Text(
                                        'Days of queries to refresh (accounts for Search Console data latency)',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: syncState.dateWindowDays,
                                  dropdownColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
                                  items: const [
                                    DropdownMenuItem(value: 7, child: Text('7 Days')),
                                    DropdownMenuItem(value: 14, child: Text('14 Days')),
                                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                                    DropdownMenuItem(value: 60, child: Text('60 Days')),
                                    DropdownMenuItem(value: 90, child: Text('90 Days')),
                                  ],
                                  onChanged: (days) {
                                    if (days != null) syncCtrl.updateDateWindowDays(days);
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.sm),

                            // Next Sync Indicator
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.amber.shade300 : Colors.amber.shade700).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      syncState.nextScheduledSync != null
                                          ? 'Next run: ${DateFormat('EEE, MMM d at h:mm a').format(syncState.nextScheduledSync!)}'
                                          : 'Schedule active (network required)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.md),

                          // Trigger manual sync now button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: syncState.isSyncing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                    )
                                  : const Icon(Icons.sync, size: 16),
                              label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync All Websites Now'),
                              onPressed: syncState.isSyncing
                                  ? null
                                  : () async {
                                      try {
                                        final res = await syncCtrl.syncAllNow();
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
                                              content: Text('Sync error: $e'),
                                              backgroundColor: AppColors.rankDrop,
                                            ),
                                          );
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: borderColor),
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
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _saveBingKey,
                            child: const Text('Save Bing Key'),
                          ),
                          OutlinedButton(
                            onPressed: _isTestingBingKey
                                ? null
                                : _testBingConnection,
                            child: _isTestingBingKey
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : const Text('Test Connection'),
                          ),
                        ],
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
                Consumer(
                  builder: (context, ref, _) {
                    final gscStatus = ref.watch(gscConnectionStatusProvider).value ??
                        GscConnectionStatus.notConfigured();

                    Color statusBg;
                    Color statusBorder;
                    Color statusColor;

                    switch (gscStatus.state) {
                      case GscConnectionState.connected:
                        statusBg = isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
                        statusBorder = isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0);
                        statusColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
                        break;
                      case GscConnectionState.readyToConnect:
                        statusBg = isDark ? const Color(0xFF1E3A8A).withAlpha(40) : const Color(0xFFEFF6FF);
                        statusBorder = isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE);
                        statusColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
                        break;
                      case GscConnectionState.connecting:
                        statusBg = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF1F5F9);
                        statusBorder = isDark ? const Color(0xFF3B82F6) : AppColors.accent;
                        statusColor = isDark ? const Color(0xFF60A5FA) : AppColors.accent;
                        break;
                      case GscConnectionState.actionRequired:
                        statusBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
                        statusBorder = isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
                        statusColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
                        break;
                      case GscConnectionState.connectionError:
                        statusBg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
                        statusBorder = isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
                        statusColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
                        break;
                      case GscConnectionState.notConfigured:
                        statusBg = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF1F5F9);
                        statusBorder = isDark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1);
                        statusColor = isDark ? AppColors.darkTextTertiary : AppColors.textSecondary;
                        break;
                    }

                    final activeEmail = _gscUserEmail ?? gscStatus.userEmail;
                    final activeSites = _gscVerifiedSites.isNotEmpty
                        ? _gscVerifiedSites
                        : gscStatus.verifiedSites;

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header + Status Pill
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.travel_explore,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Google Search Console API',
                                  style: AppTextStyles.labelLarge,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (gscStatus.isConnecting || _isSigningInGoogle) ...[
                                      SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ] else ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      gscStatus.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // State Description Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gscStatus.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                if (activeEmail != null && activeEmail.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.account_circle_outlined, size: 14, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Authorized Account: $activeEmail',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Primary Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                onPressed: _isSigningInGoogle ? null : _connectWithGoogle,
                                icon: _isSigningInGoogle
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.login, size: 16),
                                label: Text(
                                  gscStatus.isConnected
                                      ? 'Switch Google Account'
                                      : 'Connect with Google',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: (_isTestingGscToken || _isSigningInGoogle) ? null : _testGscConnection,
                                icon: _isTestingGscToken
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                      )
                                    : const Icon(Icons.verified_outlined, size: 16),
                                label: const Text('Verify API Connection'),
                              ),
                              if (gscStatus.isConnected || activeEmail != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: AppColors.rankDrop),
                                  onPressed: _disconnectGoogle,
                                  icon: const Icon(Icons.link_off, size: 16),
                                  label: const Text('Disconnect'),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Verified Properties Chips
                          if (activeSites.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.rankGain.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                                border: Border.all(
                                  color: AppColors.rankGain.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.verified,
                                        size: 16,
                                        color: AppColors.rankGain,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Connected Properties (${activeSites.length}):',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.rankGain,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: activeSites.map((site) {
                                      return Chip(
                                        label: Text(
                                          site,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // Android OAuth Client Setup Details
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: isDark ? const Color(0xFF60A5FA) : AppColors.accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Google Cloud Console OAuth Setup Instructions',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Google Sign-In on Android uses Google Credential Manager, which requires two separate OAuth Client IDs in your Google Cloud project:\n'
                                  '1. Android Client ID: Identifies this app via package name and signing SHA-1.\n'
                                  '2. Web application Client ID: Passed as serverClientId to authorize Search Console API scopes.\n'
                                  'No Client Secret is ever needed in this mobile app.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Package Name: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SelectableText('com.rankscope.app', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 14),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Copy package name',
                                      onPressed: () {
                                        Clipboard.setData(const ClipboardData(text: 'com.rankscope.app'));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Package name copied!')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text('SHA-1: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    const Expanded(
                                      child: SelectableText(
                                        '1C:7F:AA:41:93:F2:F1:58:FD:48:FE:5D:60:44:9E:9D:0A:C9:4C:77',
                                        style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 14),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Copy SHA-1 fingerprint',
                                      onPressed: () {
                                        Clipboard.setData(const ClipboardData(
                                          text: '1C:7F:AA:41:93:F2:F1:58:FD:48:FE:5D:60:44:9E:9D:0A:C9:4C:77',
                                        ));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('SHA-1 fingerprint copied!')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Note: Current release APK signing matches the debug keystore above. If using a custom production keystore or Google Play App Signing, also register that SHA-1.',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Android Client ID input field
                          const Text(
                            'Android OAuth Client ID',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'OAuth Client ID created with Application type: Android',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _gscClientController,
                                  decoration: const InputDecoration(
                                    hintText: 'your-android-client.apps.googleusercontent.com',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final id = _gscClientController.text.trim();
                                  final storage = ref.read(secureStorageServiceProvider);
                                  if (id.isNotEmpty) {
                                    await storage.saveGscClientId(id);
                                  } else {
                                    await storage.clearGscClientId();
                                  }
                                  await ref.read(gscConnectionStatusProvider.notifier).refreshStatus();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Android OAuth Client ID saved to Android KeyStore.')),
                                    );
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Web OAuth Client ID / Server Client ID input field
                          const Text(
                            'Web OAuth Client ID / Server Client ID',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'OAuth Client ID created with Application type: Web application (required on Android as serverClientId)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _gscServerClientController,
                                  decoration: const InputDecoration(
                                    hintText: 'your-web-client.apps.googleusercontent.com',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final id = _gscServerClientController.text.trim();
                                  final storage = ref.read(secureStorageServiceProvider);
                                  if (id.isNotEmpty) {
                                    await storage.saveGscServerClientId(id);
                                  } else {
                                    await storage.clearGscServerClientId();
                                  }
                                  await ref.read(gscConnectionStatusProvider.notifier).refreshStatus();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Web OAuth Client ID saved to Android KeyStore.')),
                                    );
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Expandable Advanced Manual Token Entry
                          InkWell(
                            onTap: () => setState(() => _showAdvancedGsc = !_showAdvancedGsc),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    'Advanced / Manual Token Entry',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _showAdvancedGsc ? Icons.expand_less : Icons.expand_more,
                                    size: 18,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showAdvancedGsc) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'OAuth 2.0 Access Token (Manual Override)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _gscAccessTokenController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Paste OAuth access token (ya29...)...',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_paste, size: 18),
                                  tooltip: 'Paste from clipboard',
                                  onPressed: () async {
                                    final data = await Clipboard.getData('text/plain');
                                    if (data?.text != null) {
                                      _gscAccessTokenController.text = data!.text!.trim();
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'OAuth Refresh Token (Optional)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _gscRefreshTokenController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: '1//... (for automated background token renewal)',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ElevatedButton(
                              onPressed: _saveGscCredentials,
                              child: const Text('Save Manual Tokens'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Yandex Webmaster Tools
                const Text(
                  'YANDEX WEBMASTER (OPTIONAL)',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.yandexRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.search,
                              size: 16,
                              color: AppColors.yandexRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Yandex OAuth 2.0 Token',
                            style: AppTextStyles.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Direct OAuth access to Yandex Webmaster API v4 without servers or third parties. Stored securely in Android KeyStore.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: secondaryBg,
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Required Scopes:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.yandexRed,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '• webmaster:verify (Read verification status)\n'
                              '• webmaster:hostinfo (Read search queries and hosts)',
                              style: TextStyle(fontSize: 11, height: 1.4),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Get Token: Register an app at oauth.yandex.ru with the scopes above, set Redirect URI to https://oauth.yandex.ru/verification_code, and paste the OAuth token below.',
                              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _yandexTokenController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Paste Yandex OAuth token (y0_...)...',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _saveYandexToken,
                            child: const Text('Save Yandex Token'),
                          ),
                          OutlinedButton(
                            onPressed: _isTestingYandexToken
                                ? null
                                : _testYandexConnection,
                            child: _isTestingYandexToken
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : const Text('Test Connection'),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('View Yandex Analytics'),
                            onPressed: () => context.push('/yandex-webmaster'),
                          ),
                        ],
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
                    color: secondaryBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: borderColor),
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
                const SizedBox(height: AppSpacing.lg),

                // About & Developer Attribution
                const Text(
                  'ABOUT & DEVELOPER',
                  style: AppTextStyles.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceSecondary
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.track_changes,
                              size: 20,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RankScope',
                                  style: AppTextStyles.titleMedium,
                                ),
                                Text(
                                  'v2.0.0 • Local-First SEO & Rank Intelligence',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.code,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Developer: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Bishal Aryal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () async {
                          final uri = Uri.parse(ApiDocumentationUrls.developerWebsite);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Author Website: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'https://bishalaryal.com.np',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(
                                  Icons.copy,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                                tooltip: 'Copy Author URL',
                                onPressed: () {
                                  Clipboard.setData(
                                    const ClipboardData(
                                      text: ApiDocumentationUrls.developerWebsite,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Author URL copied: https://bishalaryal.com.np',
                                      ),
                                      backgroundColor: AppColors.accent,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.explore_outlined, size: 16),
                              label: const Text('Replay App Feature Tour'),
                              onPressed: () =>
                                  context.push('/onboarding?revisit=true'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.policy_outlined, size: 16),
                              label: const Text('Open Source Licenses'),
                              onPressed: () {
                                showLicensePage(
                                  context: context,
                                  applicationName: 'RankScope',
                                  applicationVersion: 'v2.0.0',
                                  applicationLegalese:
                                      'Crafted with precision by Bishal Aryal.\nStrictly device-first, \$0 budget SEO intelligence.',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }
}

class _SettingsNavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SettingsNavCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfacePrimary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 2),
                    Text(description, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryBg =
        isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: secondaryBg,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: borderColor),
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
