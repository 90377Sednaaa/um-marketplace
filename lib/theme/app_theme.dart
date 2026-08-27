import 'package:flutter/material.dart';

/// UM Marketplace design tokens (DESIGN.md §2).
abstract final class UmColors {
  static const Color primary = Color(0xFF7C2D12); // UM maroon
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color gold = Color(0xFFFFC72C);
  static const Color goldSoft = Color(0xFFFEF3C7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF450A0A);
  static const Color muted = Color(0xFFECEDF0);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color ink = Color(0xFF000000);
  static const Color success = Color(0xFF15803D);
  static const Color destructive = Color(0xFFDC2626);
}

/// Light-only theme per DESIGN.md §1; heavy type per §3 (body never
/// thinner than 400). Neubrutalist surfaces (borders, shadows, press
/// motion) are applied per-widget via [UmColors] and components.
ThemeData buildUmTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: UmColors.background,
    colorScheme: const ColorScheme.light(
      primary: UmColors.primary,
      onPrimary: UmColors.onPrimary,
      secondary: UmColors.gold,
      onSecondary: UmColors.ink,
      error: UmColors.destructive,
      onError: UmColors.onPrimary,
      surface: UmColors.surface,
      onSurface: UmColors.onSurface,
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        height: 1.2,
        color: UmColors.onSurface,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: UmColors.onSurface,
      ),
      bodyMedium: const TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14.5,
        height: 1.45,
        color: UmColors.onSurface,
      ),
      labelMedium: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: UmColors.onSurface,
      ),
    ),
  );
}