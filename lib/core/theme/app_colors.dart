import 'package:flutter/material.dart';

/// Premium Minimalist Light-Mode Color Palette for RankScope.
/// Strictly light mode with high contrast and zero drop shadows.
class AppColors {
  AppColors._();

  // Background surfaces
  static const Color surfacePrimary = Color(0xFFFFFFFF);     // Pure canvas & modals
  static const Color surfaceSecondary = Color(0xFFF8F9FA);   // Cards, table headers, chip fills
  static const Color surfaceTertiary = Color(0xFFF1F3F5);    // Inputs & disabled states
  static const Color surfaceHover = Color(0xFFE9ECEF);       // Interactive hover/active states

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFFE9ECEF);       // Card outlines, table grid lines
  static const Color borderMedium = Color(0xFFCED4DA);       // Input borders & inactive toggles
  static const Color borderFocus = Color(0xFF212529);        // Focused inputs & active chips

  // Typography
  static const Color textPrimary = Color(0xFF1A1D20);        // Headings, primary metrics, active text
  static const Color textSecondary = Color(0xFF495057);      // Body copy, table cells, subtitles
  static const Color textTertiary = Color(0xFF868E96);       // Metadata, timestamps, placeholders
  static const Color textDisabled = Color(0xFFADB5BD);       // Disabled button labels

  // Rank Performance & Semantic Feedback
  static const Color rankGain = Color(0xFF2B8A3E);           // Position improvement (green)
  static const Color rankGainLight = Color(0xFFEBFBEE);      // Background tint for gain
  static const Color rankDrop = Color(0xFFC92A2A);           // Position decline (red)
  static const Color rankDropLight = Color(0xFFFFF5F5);      // Background tint for drop
  static const Color rankStable = Color(0xFF868E96);         // Unchanged position (neutral)
  static const Color rankStableLight = Color(0xFFF1F3F5);    // Background tint for stable

  // SERP Accents
  static const Color rankTop3 = Color(0xFFD97706);           // Rank 1-3 Gold/Amber badge
  static const Color rankTop3Light = Color(0xFFFEF3C7);
  static const Color rankTop10 = Color(0xFF2563EB);          // Rank 4-10 Blue badge
  static const Color rankTop10Light = Color(0xFFEFF6FF);

  // Brand / Interactive Accent
  static const Color accent = Color(0xFF0F172A);             // Deep slate black primary action
  static const Color accentLight = Color(0xFFF1F5F9);
}
