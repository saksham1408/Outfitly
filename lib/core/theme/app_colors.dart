import 'package:flutter/material.dart';

/// Outfitly brand color palette — extracted from the Stitch design system.
abstract final class AppColors {
  // ── Primary (Deep Forest Green) ──
  static const Color primary = Color(0xFF17362E);
  static const Color primaryLight = Color(0xFF2E4D44);     // primary-container
  static const Color primaryDark = Color(0xFF002019);

  // ── Secondary / Accent (Amber) ──
  static const Color accent = Color(0xFF8B500A);            // secondary
  static const Color accentLight = Color(0xFFFFB876);       // secondary-fixed-dim
  static const Color accentDark = Color(0xFF6B3B00);
  static const Color accentContainer = Color(0xFFFFB065);   // secondary-container

  // ── Surface & Background ──
  static const Color background = Color(0xFFFCF9F6);        // surface / background
  static const Color surface = Color(0xFFFFFFFF);            // surface-container-lowest
  static const Color surfaceVariant = Color(0xFFE5E2E0);     // surface-variant
  static const Color surfaceContainer = Color(0xFFF0EDEB);   // surface-container
  static const Color surfaceContainerHigh = Color(0xFFEAE8E5);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1C1C1B);       // on-surface
  static const Color textSecondary = Color(0xFF414845);      // on-surface-variant
  static const Color textTertiary = Color(0xFF717975);       // outline
  static const Color textOnPrimary = Color(0xFFFFFFFF);      // on-primary
  static const Color textOnAccent = Color(0xFFFFFFFF);       // on-secondary

  // ── Semantic ──
  static const Color success = Color(0xFF2E7D4F);
  static const Color error = Color(0xFFBA1A1A);              // error
  static const Color warning = Color(0xFFE6A817);
  static const Color info = Color(0xFF3B7FBF);

  // ── Border & Divider ──
  static const Color border = Color(0xFFC1C8C4);            // outline-variant
  static const Color divider = Color(0xFFEDE9E3);

  // ── Misc ──
  static const Color shadow = Color(0x1A000000);
  static const Color shimmerBase = Color(0xFFE0DCD5);
  static const Color shimmerHighlight = Color(0xFFF5F2ED);

  // ── Glass effect ──
  static const Color glassBackground = Color(0xBFFCF9F6);   // 75% opacity surface
  static const Color glassBorder = Color(0x4DFFFFFF);        // 30% white
}
