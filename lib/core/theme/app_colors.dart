import 'package:flutter/material.dart';

/// Premium Minimalist Light-Mode Color Palette for RankScope.
/// Strictly light mode with high contrast and zero drop shadows.
class AppColors {
  AppColors._();

  // Background surfaces
  static const Color surfacePrimary = Color(0xFFFFFFFF); // Pure canvas & modals
  static const Color surfaceSecondary = Color(
    0xFFF8F9FA,
  ); // Cards, table headers, chip fills
  static const Color surfaceTertiary = Color(
    0xFFF1F3F5,
  ); // Inputs & disabled states
  static const Color surfaceHover = Color(
    0xFFE9ECEF,
  ); // Interactive hover/active states

  // Borders & Dividers
  static const Color borderSubtle = Color(
    0xFFE9ECEF,
  ); // Card outlines, table grid lines
  static const Color borderMedium = Color(
    0xFFCED4DA,
  ); // Input borders & inactive toggles
  static const Color borderFocus = Color(
    0xFF212529,
  ); // Focused inputs & active chips

  // Typography
  static const Color textPrimary = Color(
    0xFF1A1D20,
  ); // Headings, primary metrics, active text
  static const Color textSecondary = Color(
    0xFF495057,
  ); // Body copy, table cells, subtitles
  static const Color textTertiary = Color(
    0xFF868E96,
  ); // Metadata, timestamps, placeholders
  static const Color textDisabled = Color(0xFFADB5BD); // Disabled button labels

  // Rank Performance & Semantic Feedback
  static const Color rankGain = Color(
    0xFF2B8A3E,
  ); // Position improvement (green)
  static const Color rankGainLight = Color(
    0xFFEBFBEE,
  ); // Background tint for gain
  static const Color rankDrop = Color(0xFFC92A2A); // Position decline (red)
  static const Color rankDropLight = Color(
    0xFFFFF5F5,
  ); // Background tint for drop
  static const Color rankStable = Color(
    0xFF868E96,
  ); // Unchanged position (neutral)
  static const Color rankStableLight = Color(
    0xFFF1F3F5,
  ); // Background tint for stable

  // SERP Accents
  static const Color rankTop3 = Color(0xFFD97706); // Rank 1-3 Gold/Amber badge
  static const Color rankTop3Light = Color(0xFFFEF3C7);
  static const Color rankTop10 = Color(0xFF2563EB); // Rank 4-10 Blue badge
  static const Color rankTop10Light = Color(0xFFEFF6FF);

  // Brand / Interactive Accent
  static const Color accent = Color(
    0xFF0F172A,
  ); // Deep slate black primary action
  static const Color accentLight = Color(0xFFF1F5F9);

  // Dark Mode Palette
  static const Color darkBackground = Color(0xFF0B0F19); // Main canvas in dark mode
  static const Color darkCard = Color(0xFF111827); // Elevated cards & containers
  static const Color darkSurfaceSecondary = Color(0xFF1F2937); // Inputs, chips, secondary surfaces
  static const Color darkSurfaceTertiary = Color(0xFF374151); // Disabled & subtle borders
  static const Color darkSurfaceHover = Color(0xFF1E293B);

  static const Color darkBorderSubtle = Color(0xFF1F2937);
  static const Color darkBorderMedium = Color(0xFF374151);
  static const Color darkBorderFocus = Color(0xFF60A5FA);

  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);
  static const Color darkTextDisabled = Color(0xFF4B5563);

  static const Color darkAccent = Color(0xFF38BDF8);
  static const Color darkAccentLight = Color(0xFF1E293B);

  static const Color darkRankGain = Color(0xFF22C55E);
  static const Color darkRankGainLight = Color(0xFF052E16);
  static const Color darkRankDrop = Color(0xFFEF4444);
  static const Color darkRankDropLight = Color(0xFF450A0A);
  static const Color darkRankStable = Color(0xFF9CA3AF);
  static const Color darkRankStableLight = Color(0xFF1F2937);

  static const Color darkRankTop3 = Color(0xFFF59E0B);
  static const Color darkRankTop3Light = Color(0xFF451A03);
  static const Color darkRankTop10 = Color(0xFF60A5FA);
  static const Color darkRankTop10Light = Color(0xFF172554);

  /// Engine Brand Accents
  static const Color engineGoogle = Color(0xFF4285F4);
  static const Color engineBing = Color(0xFF008373);
  static const Color engineYandex = Color(0xFFFC3F1D);

  static const Color googleBlue = engineGoogle;
  static const Color yandexRed = engineYandex;
  static const Color darkBorder = darkBorderSubtle;

  // Glassmorphism & Translucent Surfaces
  static const Color glassLightBg = Color(0xF2FFFFFF); // 95% opacity white fallback/fill
  static const Color glassLightSurface = Color(0xCCF8FAFC); // 80% opacity soft blue-white
  static const Color glassLightBorder = Color(0x59CBD5E1); // Subtle frosted border
  static const Color glassLightShadow = Color(0x0A0F172A); // Softest slate drop shadow

  static const Color glassDarkBg = Color(0xF2111827); // 95% opacity dark fallback/fill
  static const Color glassDarkSurface = Color(0xCC1E293B); // 80% opacity dark slate
  static const Color glassDarkBorder = Color(0x40374151); // Translucent dark border
  static const Color glassDarkShadow = Color(0x33000000); // Deep dark shadow
}
