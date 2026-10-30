import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rankscope/core/security/secure_storage_service.dart';
import 'package:rankscope/core/theme/app_colors.dart';
import 'package:rankscope/core/theme/app_text_styles.dart';
import 'package:rankscope/core/theme/spacing.dart';
import 'package:rankscope/features/backup_restore/data/services/backup_restore_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
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
    } else {
      await storage.clearBingCredentials();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bing API credentials saved to Android KeyStore.')),
      );
    }
  }

  Future<void> _saveGscClientId() async {
    final storage = ref.read(secureStorageServiceProvider);
    final id = _gscClientController.text.trim();
    if (id.isNotEmpty) {
      await storage.saveGscClientId(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google OAuth Client ID saved.')),
      );
    }
  }

  Future<void> _exportBackup() async {
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final bundle = await service.createBackupBundle();
      final jsonString = jsonEncode(bundle);

      final dir = await getApplicationDocumentsDirectory();
      final backupFile = File('${dir.path}/RankScope_Backup_${DateTime.now().millisecondsSinceEpoch}.rankscope');
      await backupFile.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupFile.path)],
          subject: 'RankScope Air-Gapped Database Backup (SHA-256 Verified)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        title: const Text('Settings & Privacy', style: AppTextStyles.titleLarge),
      ),
      body: _isLoadingKeys
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Air-Gapped Backup & Restore
                const Text('DATABASE & BACKUP', style: AppTextStyles.labelSmall),
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
                      const Text('Air-Gapped Local Backup', style: AppTextStyles.labelLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Export your entire SQLite database and audit history into an encrypted or raw .rankscope bundle with SHA-256 integrity verification.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Export Backup'),
                            onPressed: _exportBackup,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bing API Integration
                const Text('BING WEBMASTER TOOLS (OPTIONAL)', style: AppTextStyles.labelSmall),
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
                      const Text('Bing Free API Key', style: AppTextStyles.labelLarge),
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
                const Text('GOOGLE SEARCH CONSOLE (OPTIONAL)', style: AppTextStyles.labelSmall),
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
                      const Text('Google Cloud OAuth Client ID', style: AppTextStyles.labelLarge),
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
                const Text('DATA SOVEREIGNTY & PRIVACY', style: AppTextStyles.labelSmall),
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
                          Icon(Icons.lock_outline, size: 18, color: AppColors.rankGain),
                          SizedBox(width: 8),
                          Text('100% Device-Only Privacy', style: AppTextStyles.labelLarge),
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
