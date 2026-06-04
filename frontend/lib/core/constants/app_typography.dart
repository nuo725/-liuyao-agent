import 'package:flutter/material.dart';

/// Global typography tokens - fresh, clean, modern
class AppTypography {
  AppTypography._();

  // Font families
  static const String fontSerif = 'Noto Serif SC';
  static const String fontSans = 'Noto Sans SC';
  static const String fontDisplay = 'LXGW WenKai';

  // ─────────────────────────────────────────────────────────────────
  // DISPLAY - Large titles, hero text
  // ─────────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 36,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 30,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.25,
    color: Color(0xFF1A1A1A),
  );

  // ─────────────────────────────────────────────────────────────────
  // HEADLINES - Section titles
  // ─────────────────────────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontSerif,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontSerif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.35,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontSerif,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: Color(0xFF1A1A1A),
  );

  // ─────────────────────────────────────────────────────────────────
  // BODY - Main content text
  // ─────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontSans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.7,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontSans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
    height: 1.65,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontSans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
    height: 1.55,
    color: Color(0xFF1A1A1A),
  );

  // ─────────────────────────────────────────────────────────────────
  // LABELS - Buttons, tags, small UI elements
  // ─────────────────────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontSans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.3,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontSans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.3,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontSans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
    color: Color(0xFF1A1A1A),
  );

  // ─────────────────────────────────────────────────────────────────
  // SPECIAL - Button text, captions, quotes
  // ─────────────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: fontSans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontSans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.35,
    color: Color(0xFF8A8A8A),
  );

  static const TextStyle quote = TextStyle(
    fontFamily: fontSerif,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.8,
    fontStyle: FontStyle.italic,
    color: Color(0xFF1A1A1A),
  );
}
