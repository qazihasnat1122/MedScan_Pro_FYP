import 'package:flutter/material.dart';

/// Deep Teal Design System Tokens for MedScan Pro.
/// Strictly enforces the brand palette (#071417 background, #087F8C primary teal,
/// #16B8A6 accent, #F4FAFA text) with consistent card elevations and unified typography.
class MedScanTheme {
  // ── Strict Color Palette ──────────────────────────────────────────────────
  static const Color background = Color(
    0xFF071417,
  ); // Deepest clinical teal/black
  static const Color surface = Color(0xFF0C2227); // Dark teal surface
  static const Color surfaceCard = Color(0xFF0E2A30); // Card container
  static const Color surfaceElevated = Color(
    0xFF143840,
  ); // Hover/Elevated container
  static const Color surfaceHighlight = Color(0xFF1A4650); // Subtle highlight

  static const Color primaryTeal = Color(
    0xFF087F8C,
  ); // Primary brand medical teal
  static const Color accentTeal = Color(
    0xFF16B8A6,
  ); // High-contrast mint accent
  static const Color secondaryTeal = Color(0xFF056674); // Deep brand tone
  static const Color lightTealTint = Color(
    0xFFE6F7F8,
  ); // Very soft tint for chips

  static const Color border = Color(0xFF1B4A54); // Slate-teal border
  static const Color borderSubtle = Color(0xFF13363D); // Inactive border

  // Typography Colors
  static const Color textPrimary = Color(0xFFF4FAFA); // Crisp white-teal
  static const Color textSecondary = Color(0xFFCBD5E1); // Soft slate
  static const Color textMuted = Color(0xFF8FAEB5); // Muted teal-slate
  static const Color textDark = Color(
    0xFF071417,
  ); // Inverted text for bright badges

  // ── 5 Official Project Verification State Colors ──────────────────────────
  // 1. Manufacturer-supported verification (Verified Green)
  static const Color stateVerified = Color(0xFF10B981);
  static const Color stateVerifiedBg = Color(0xFF064E3B);
  static const Color stateVerifiedBorder = Color(0xFF059669);

  // 2. Reference information available (Informational Blue)
  static const Color stateReference = Color(0xFF38BDF8);
  static const Color stateReferenceBg = Color(0xFF0C4A6E);
  static const Color stateReferenceBorder = Color(0xFF0284C7);

  // 3. Limited verification (Neutral Gray)
  static const Color stateLimited = Color(0xFF94A3B8);
  static const Color stateLimitedBg = Color(0xFF1E293B);
  static const Color stateLimitedBorder = Color(0xFF475569);

  // 4. Suspicious indicators detected (Warning Amber/Red)
  static const Color stateSuspicious = Color(0xFFEF4444);
  static const Color stateSuspiciousBg = Color(0xFF450A0A);
  static const Color stateSuspiciousBorder = Color(0xFFDC2626);

  // 5. No reference found (Helpful Discovery State)
  static const Color stateNoReference = Color(0xFFF59E0B);
  static const Color stateNoReferenceBg = Color(0xFF451A03);
  static const Color stateNoReferenceBorder = Color(0xFFD97706);

  // ── Radii & Elevations ────────────────────────────────────────────────────
  static const double radiusCard = 16.0;
  static const double radiusChip = 8.0;
  static const double radiusInput = 12.0;
  static const double radiusButton = 12.0;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glowingTealShadow => [
    BoxShadow(
      color: primaryTeal.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // ── Unified Typography Hierarchy ──────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: textMuted,
    height: 1.35,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
}
