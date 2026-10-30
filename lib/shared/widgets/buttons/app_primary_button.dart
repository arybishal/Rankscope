import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/spacing.dart';

/// Clean, high-contrast primary button with optional loading indicator.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final bool isFullWidth;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.surfacePrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: onPressed == null
                ? AppColors.textDisabled
                : AppColors.surfacePrimary,
          ),
        ),
      ],
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surfaceTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          elevation: 0,
        ),
        child: buttonContent,
      ),
    );
  }
}
