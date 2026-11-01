import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/keywords/presentation/controllers/keywords_controller.dart';

/// Dialog to customize ranking alert thresholds, enabled triggers, and local notifications.
class AlertSettingsDialog extends ConsumerStatefulWidget {
  const AlertSettingsDialog({super.key});

  @override
  ConsumerState<AlertSettingsDialog> createState() =>
      _AlertSettingsDialogState();
}

class _AlertSettingsDialogState extends ConsumerState<AlertSettingsDialog> {
  late int _rankGainThreshold;
  late int _rankDropThreshold;
  late bool _rankGainEnabled;
  late bool _rankDropEnabled;
  late bool _newQueryEnabled;
  late bool _lostQueryEnabled;
  late bool _urlChangeEnabled;
  late bool _cannibalizationEnabled;
  late bool _localNotificationsEnabled;
  bool _isLoaded = false;
  bool _isSaving = false;

  void _initFromSettings(AlertSettings settings) {
    if (_isLoaded) return;
    _rankGainThreshold = settings.rankGainThreshold;
    _rankDropThreshold = settings.rankDropThreshold;
    _rankGainEnabled = settings.rankGainEnabled;
    _rankDropEnabled = settings.rankDropEnabled;
    _newQueryEnabled = settings.newQueryEnabled;
    _lostQueryEnabled = settings.lostQueryEnabled;
    _urlChangeEnabled = settings.urlChangeEnabled;
    _cannibalizationEnabled = settings.cannibalizationEnabled;
    _localNotificationsEnabled = settings.localNotificationsEnabled;
    _isLoaded = true;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final updated = AlertSettings(
      rankGainThreshold: _rankGainThreshold,
      rankDropThreshold: _rankDropThreshold,
      rankGainEnabled: _rankGainEnabled,
      rankDropEnabled: _rankDropEnabled,
      newQueryEnabled: _newQueryEnabled,
      lostQueryEnabled: _lostQueryEnabled,
      urlChangeEnabled: _urlChangeEnabled,
      cannibalizationEnabled: _cannibalizationEnabled,
      localNotificationsEnabled: _localNotificationsEnabled,
    );

    try {
      await ref.read(alertSettingsProvider.notifier).updateSettings(updated);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ranking alert settings updated.'),
            backgroundColor: AppColors.rankGain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(alertSettingsProvider);

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: settingsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (err, _) => Center(
              child: Text('Error loading settings: $err'),
            ),
            data: (settings) {
              _initFromSettings(settings);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              color: AppColors.accent),
                          SizedBox(width: 8),
                          Text('Ranking Alert Settings',
                              style: AppTextStyles.titleLarge),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    'Configure threshold sensitivity and notification alerts. Minor daily fluctuations are ignored.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Expanded(
                    child: ListView(
                      children: [
                        // Thresholds Section
                        _buildSectionHeader('Threshold Sensitivity', isDark),
                        const SizedBox(height: 8),
                        _buildThresholdCard(
                          title: 'Rank Gain Threshold (positions)',
                          subtitle: 'Alert when a keyword climbs by at least this many positions',
                          value: _rankGainThreshold,
                          minValue: 1,
                          maxValue: 20,
                          color: AppColors.rankGain,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _rankGainThreshold = v),
                        ),
                        const SizedBox(height: 10),
                        _buildThresholdCard(
                          title: 'Rank Drop Threshold (positions)',
                          subtitle: 'Alert when a keyword slips by at least this many positions',
                          value: _rankDropThreshold,
                          minValue: 1,
                          maxValue: 20,
                          color: AppColors.rankDrop,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _rankDropThreshold = v),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Alert Types Section
                        _buildSectionHeader('Alert Triggers', isDark),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Significant Rank Improvements',
                          subtitle: 'Trigger when rank gains exceed threshold',
                          value: _rankGainEnabled,
                          icon: Icons.trending_up,
                          iconColor: AppColors.rankGain,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _rankGainEnabled = v),
                        ),
                        _buildSwitchTile(
                          title: 'Significant Rank Declines',
                          subtitle: 'Trigger when rank drops exceed threshold',
                          value: _rankDropEnabled,
                          icon: Icons.trending_down,
                          iconColor: AppColors.rankDrop,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _rankDropEnabled = v),
                        ),
                        _buildSwitchTile(
                          title: 'Newly Appearing Queries',
                          subtitle: 'Trigger when new keywords enter search impressions/rankings',
                          value: _newQueryEnabled,
                          icon: Icons.fiber_new,
                          iconColor: const Color(0xFF16A34A),
                          isDark: isDark,
                          onChanged: (v) => setState(() => _newQueryEnabled = v),
                        ),
                        _buildSwitchTile(
                          title: 'Lost Rankings',
                          subtitle: 'Trigger when a tracked keyword drops completely out of top 100',
                          value: _lostQueryEnabled,
                          icon: Icons.cancel_outlined,
                          iconColor: AppColors.rankDrop,
                          isDark: isDark,
                          onChanged: (v) => setState(() => _lostQueryEnabled = v),
                        ),
                        _buildSwitchTile(
                          title: 'Ranking URL Changes',
                          subtitle: 'Trigger when search engine switches the active landing page',
                          value: _urlChangeEnabled,
                          icon: Icons.swap_horiz,
                          iconColor: const Color(0xFF7C3AED),
                          isDark: isDark,
                          onChanged: (v) => setState(() => _urlChangeEnabled = v),
                        ),
                        _buildSwitchTile(
                          title: 'Keyword Cannibalization',
                          subtitle: 'Trigger when multiple URLs compete for impressions on the same query',
                          value: _cannibalizationEnabled,
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFDC2626),
                          isDark: isDark,
                          onChanged: (v) =>
                              setState(() => _cannibalizationEnabled = v),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Notifications Delivery
                        _buildSectionHeader('Device Delivery', isDark),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Android Local Notifications',
                          subtitle: 'Post high & warning priority alerts to device notification bar',
                          value: _localNotificationsEnabled,
                          icon: Icons.notifications_active,
                          iconColor: AppColors.accent,
                          isDark: isDark,
                          onChanged: (v) =>
                              setState(() => _localNotificationsEnabled = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Alert Preferences',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildThresholdCard({
    required String title,
    required String subtitle,
    required int value,
    required int minValue,
    required int maxValue,
    required Color color,
    required bool isDark,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '≥ $value pos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: minValue.toDouble(),
            max: maxValue.toDouble(),
            divisions: maxValue - minValue,
            activeColor: color,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
      ),
      child: SwitchListTile(
        value: value,
        activeThumbColor: AppColors.accent,
        secondary: Icon(icon, color: iconColor, size: 20),
        title: Text(title, style: AppTextStyles.labelMedium),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
