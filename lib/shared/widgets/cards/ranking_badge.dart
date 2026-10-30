import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/spacing.dart';

/// Minimalist chip displaying an exact rank position and optional movement delta.
class RankingBadge extends StatelessWidget {
  final int? position;
  final int? delta; // Positive = gained rank (e.g. +3), Negative = dropped rank
  final bool showDelta;
  final String? statusLabel; // e.g. 'Pending', 'Paused', 'Error'

  const RankingBadge({
    super.key,
    required this.position,
    this.delta,
    this.showDelta = true,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (statusLabel != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceTertiary,
          borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          statusLabel!,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (position == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceTertiary,
          borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Text('—', style: AppTextStyles.labelSmall),
      );
    }

    if (position == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final pos = position!;
    Color badgeColor = AppColors.surfaceSecondary;
    Color textColor = AppColors.textPrimary;
    Color borderColor = AppColors.borderSubtle;

    if (pos <= 3) {
      badgeColor = AppColors.rankTop3Light;
      textColor = AppColors.rankTop3;
      borderColor = AppColors.rankTop3.withAlpha(77); // ~0.3 opacity
    } else if (pos <= 10) {
      badgeColor = AppColors.rankTop10Light;
      textColor = AppColors.rankTop10;
      borderColor = AppColors.rankTop10.withAlpha(77);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$pos',
            style: AppTextStyles.labelMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showDelta && delta != null && delta != 0) ...[
            const SizedBox(width: 4),
            _buildDeltaWidget(delta!),
          ],
        ],
      ),
    );
  }

  Widget _buildDeltaWidget(int d) {
    final isGain = d > 0;
    final icon = isGain ? '▲' : '▼';
    final color = isGain ? AppColors.rankGain : AppColors.rankDrop;
    final text = '$icon${d.abs()}';

    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
