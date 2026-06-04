import 'package:flutter/material.dart';

/// Global color tokens for the Zhouyi visual system.
/// Fresh, youthful, minimalist palette inspired by iCity
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════
  // PRIMARY BRAND COLORS - Fresh & Youthful
  // ═══════════════════════════════════════════════════════════════════

  /// Mint green - primary brand color for young, fresh feel
  static const Color mint = Color(0xFFE8F5F0);
  static const Color mintLight = Color(0xFFF5FCFA);
  static const Color mintDark = Color(0xFFB8DFD0);

  /// Soft blue - secondary accent
  static const Color sky = Color(0xFFF0F7FF);
  static const Color skyDark = Color(0xFFD4E8FF);

  /// Blush pink - warm accent
  static const Color blush = Color(0xFFFFF5F5);
  static const Color blushDark = Color(0xFFFFD9D9);

  /// Cream - warm neutral background
  static const Color cream = Color(0xFFFCFCF8);

  /// Lavender - subtle accent
  static const Color lavender = Color(0xFFF5F3FF);
  static const Color lavenderDark = Color(0xFFE4DFFF);

  // ═══════════════════════════════════════════════════════════════════
  // FOUNDATION COLORS
  // ═══════════════════════════════════════════════════════════════════

  /// Pure white background
  static const Color paper = Color(0xFFFFFFFF);

  /// Off-white for subtle backgrounds
  static const Color paperShade = Color(0xFFFAFAFA);

  /// Primary ink - deep charcoal
  static const Color ink = Color(0xFF1A1A1A);

  /// Soft ink for secondary text
  static const Color inkSoft = Color(0xFF6B6B6B);

  /// Light border color
  static const Color border = Color(0xFFEEEEEE);
  static const Color borderLight = Color(0xFFF5F5F5);

  /// Subtle divider
  static const Color divider = Color(0xFFF5F5F5);

  // ═══════════════════════════════════════════════════════════════════
  // SURFACE COLORS
  // ═══════════════════════════════════════════════════════════════════

  /// Main surface color (white)
  static const Color surface = paper;

  /// Card surface with subtle warm tint
  static const Color surfaceCard = Color(0xFFFFFEFC);

  /// Surface variant
  static const Color surfaceVariant = paperShade;

  // ═══════════════════════════════════════════════════════════════════
  // TEXT COLORS
  // ═══════════════════════════════════════════════════════════════════

  /// Primary text - deep charcoal
  static const Color textPrimary = ink;

  /// Secondary text - soft gray
  static const Color textSecondary = inkSoft;

  /// Tertiary text - light gray
  static const Color textTertiary = Color(0xFFAAAAAA);

  /// Inverse text (on dark backgrounds)
  static const Color textInverse = paper;

  // ═══════════════════════════════════════════════════════════════════
  // ACCENT & FEEDBACK COLORS
  // ═══════════════════════════════════════════════════════════════════

  /// Primary action color - using mint green as brand
  static const Color primary = Color(0xFF4CAF82);
  static const Color primaryLight = mint;
  static const Color primaryDark = Color(0xFF3D8B6A);

  /// Accent - coral for warmth
  static const Color accent = Color(0xFFFF7B6B);
  static const Color accentLight = blush;
  static const Color accentWarm = Color(0xFFFFAA98);

  /// Success - fresh green
  static const Color success = Color(0xFF66BB8A);

  /// Warning - soft amber
  static const Color warning = Color(0xFFFFB74D);

  /// Error - soft red
  static const Color error = Color(0xFFE57373);

  /// Info - soft blue
  static const Color info = Color(0xFF64B5F6);

  // ═══════════════════════════════════════════════════════════════════
  // SHADOW & EFFECT COLORS
  // ═══════════════════════════════════════════════════════════════════

  /// Light shadow - subtle elevation
  static const Color shadowLight = Color(0x0A000000);

  /// Medium shadow - card elevation
  static const Color shadowMedium = Color(0x14000000);

  /// Soft shadow for floating elements
  static const Color shadowSoft = Color(0x0F000000);

  // ═══════════════════════════════════════════════════════════════════
  // PATTERN & RITUAL COLORS
  // ═══════════════════════════════════════════════════════════════════

  /// Yang line color (solid)
  static const Color patternYang = ink;

  /// Yin line color (broken)
  static const Color patternYin = Color(0xFFB2B2B2);

  /// Pattern dot
  static const Color patternDot = ink;

  // ═══════════════════════════════════════════════════════════════════
  // EXTENDED VISUAL SYSTEM — INS-style content richness
  // ═══════════════════════════════════════════════════════════════════

  /// Warm canvas — slightly warmer than cream for paper-like surfaces
  static const Color canvasWarm = Color(0xFFFAF8F5);

  /// Lighter ink for secondary headings
  static const Color inkLight = Color(0xFF3A3A3A);

  /// Gold accent for ritual/ceremony highlights (coin edges, premium touches)
  static const Color goldAccent = Color(0xFFD4A843);
  static const Color goldAccentLight = Color(0xFFF5EDD8);

  /// Vibe tags — emotional atmosphere labels for content
  static const Color vibeTag1 = Color(0xFF8EC5B0); // #当下 — calm blue-green
  static const Color vibeTag2 = Color(0xFFB5A5C8); // #内耗 — muted lavender
  static const Color vibeTag3 = Color(0xFFE8C5A0); // #希望 — warm amber
  static const Color vibeTag4 = Color(0xFFC5B5D4); // #行动 — soft purple

  /// Activity status colors
  static const Color statusActive = Color(0xFF66BB8A); // 进行中 — fresh green
  static const Color statusUpcoming = Color(0xFF7EB5E8); // 预告 — soft blue
  static const Color statusEnded = Color(0xFFAAAAAA); // 已结束 — muted gray

  // ═══════════════════════════════════════════════════════════════════
  // LEGACY COMPATIBILITY ALIASES
  // ═══════════════════════════════════════════════════════════════════

  /// @deprecated Use primary instead
  static const Color jade = primary;

  /// @deprecated Use accent instead
  static const Color vermilion = accent;

  /// @deprecated Use ink instead
  static const Color night = ink;

  /// @deprecated Use surface instead
  static const Color surfaceWarm = surface;

  /// @deprecated Use surfaceCard instead
  static const Color background = paper;

  /// @deprecated Use paperShade instead
  static const Color backgroundDark = paperShade;
}
