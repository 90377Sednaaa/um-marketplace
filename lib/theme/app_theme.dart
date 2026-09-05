import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/brutal_page_route.dart';

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

/// Neubrutalist shadow tokens (DESIGN.md §4) — hard, blur 0.
abstract final class UmShadows {
  static const Offset small = Offset(3, 3);
  static const Offset card = Offset(4, 4);
  static const Offset hero = Offset(6, 6);
}

/// Light-only theme per DESIGN.md §1; Space Grotesk brutal display +
/// Outfit clean body per §3 (body never thinner than 400).
/// Neubrutalist surfaces (borders, shadows, press motion) are applied
/// per-widget via [UmColors]/[UmShadows] and components.
ThemeData buildUmTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: UmColors.background,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: BrutalPageTransitionsBuilder(),
        TargetPlatform.iOS: BrutalPageTransitionsBuilder(),
      },
    ),
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
      // Brutal display — Space Grotesk 700-800, tight, uppercase-ready.
      displayLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w800,
        fontSize: 32,
        height: 1.1,
        letterSpacing: -0.5,
        color: UmColors.onSurface,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        height: 1.2,
        letterSpacing: -0.3,
        color: UmColors.onSurface,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.25,
        color: UmColors.onSurface,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.3,
        color: UmColors.onSurface,
      ),
      // Clean body — Outfit 400-600, airy.
      bodyMedium: GoogleFonts.outfit(
        fontWeight: FontWeight.w400,
        fontSize: 14.5,
        height: 1.45,
        color: UmColors.onSurface,
      ),
      bodySmall: GoogleFonts.outfit(
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.4,
        color: UmColors.mutedForeground,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.5,
        color: UmColors.onSurface,
      ),
      labelMedium: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: UmColors.onSurface,
      ),
      labelSmall: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
        letterSpacing: 0.4,
        color: UmColors.mutedForeground,
      ),
    ),
  );
}
