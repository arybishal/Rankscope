import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/spacing.dart';

/// Reusable restrained glassmorphism container.
/// Provides soft translucent surfaces, subtle gradient, frosted blur,
/// and accessible solid fallback for both light and dark themes.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onTap,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.cardRadius);

    final border = Border.all(
      color: borderColor ?? (isDark ? AppColors.glassDarkBorder : AppColors.glassLightBorder),
      width: borderWidth,
    );

    final gradient = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E293B).withValues(alpha: 0.82),
              const Color(0xFF0F172A).withValues(alpha: 0.75),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.88),
              const Color(0xFFF1F5F9).withValues(alpha: 0.75),
            ],
          );

    final shadow = BoxShadow(
      color: isDark ? AppColors.glassDarkShadow : AppColors.glassLightShadow,
      blurRadius: 12,
      offset: const Offset(0, 4),
    );

    Widget boxContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        border: border,
        boxShadow: [shadow],
      ),
      child: child,
    );

    if (enableBlur) {
      boxContent = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: boxContent,
        ),
      );
    } else {
      boxContent = ClipRRect(
        borderRadius: radius,
        child: boxContent,
      );
    }

    if (margin != null) {
      boxContent = Padding(padding: margin!, child: boxContent);
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: boxContent,
        ),
      );
    }

    return boxContent;
  }
}
