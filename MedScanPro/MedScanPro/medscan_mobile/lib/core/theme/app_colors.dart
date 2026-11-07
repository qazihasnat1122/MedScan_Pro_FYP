import 'package:flutter/material.dart';

/// Design tokens and unified medical color palette for MedScan Pro.
/// Strict medical teal/green brand colors, neutral clinical surfaces,
/// and Material 3 elevation definitions.
class AppColors {
  // ── Brand Identity: Clinical Medical Teal ─────────────────────────────
  static const Color primary = Color(
    0xFF087F8C,
  ); // Preferred Primary Brand Teal
  static const Color primaryLight = Color(0xFF16B8A6); // Bright Mint highlight
  static const Color primaryDark = Color(0xFF056674); // Deep Brand Teal
  static const Color primaryUltraDark = Color(
    0xFF071417,
  ); // Darkest teal background

  // Secondary / Clinical Accents
  static const Color mintAccent = Color(
    0xFF16B8A6,
  ); // High-contrast mint accent
  static const Color accent = Color(0xFF0284C7); // Clinical Azure Blue
  static const Color softMint = Color(0xFFE0F2F1); // Clean Mint surface tint
  static const Color emerald = Color(0xFF10B981); // High compliance green

  // ── Light Theme Surfaces (Clean, Crisp, Medical Slate) ────────────────
  static const Color lightBg = Color(0xFFF8FAFC); // Slate-50 background
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white card
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate-200 border
  static const Color lightSubtle = Color(0xFFF1F5F9); // Slate-100 neutral fill

  // Light Theme Typography
  static const Color textDark = Color(0xFF0F172A); // Slate-900 primary text
  static const Color textSecondary = Color(0xFF334155); // Slate-700
  static const Color textMuted = Color(0xFF64748B); // Slate-500 secondary
  static const Color textLightMuted = Color(0xFF94A3B8); // Slate-400 hint

  // ── Dark Theme Surfaces (Deep Teal Clinical Palette) ──────────────────
  static const Color darkBg = Color(
    0xFF071417,
  ); // Deepest clinical teal (#071417)
  static const Color darkCard = Color(
    0xFF0D2023,
  ); // Preferred dark surface (#0D2023)
  static const Color darkBorder = Color(0xFF1B4A54); // Slate-teal border
  static const Color darkSubtle = Color(
    0xFF12292D,
  ); // Secondary surface container (#12292D)

  // Dark Theme Typography
  static const Color textLight = Color(
    0xFFF4FAFA,
  ); // Crisp white-teal text (#F4FAFA)
  static const Color textLightSecondary = Color(
    0xFFA8BEC1,
  ); // Secondary text (#A8BEC1)
  static const Color textMutedDark = Color(0xFF8FAEB5); // Muted slate-teal

  // ── Clinical & Regulatory Status Flags ────────────────────────────────
  static const Color success = Color(0xFF10B981); // Verified genuine
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(
    0xFFF59E0B,
  ); // Inspection required / recall
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444); // Counterfeit alert / danger
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6); // Clinical info
  static const Color infoBg = Color(0xFFEFF6FF);

  // ── Drop Shadow Tokens (Material 3 Subtle Elevation) ──────────────────
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get cardElevation => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get deepCardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.35),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // Backwards compatibility aliases
  static const Color background = lightBg;
  static const Color text = textDark;
}
