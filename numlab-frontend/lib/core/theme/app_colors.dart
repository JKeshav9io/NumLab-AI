import 'package:flutter/material.dart';

/// Centralized color palette for NumLab AI.
/// Defines brand colors, semantic state colors (aligned with solver outcomes),
/// and surface tones for light and dark themes.
abstract final class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4338CA);

  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color secondary = Color(0xFF8B5CF6); // Purple

  // Semantic Status Colors (aligned with solver convergence & HTTP codes)
  static const Color success = Color(0xFF10B981); // Converged
  static const Color error = Color(0xFFEF4444); // Failed / Server Error
  static const Color warning = Color(0xFFF59E0B); // Max Iterations / Warning
  static const Color info = Color(0xFF3B82F6); // AI / Notice

  // Dark Theme Neutral Surfaces
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCard = Color(0xFF334155); // Slate 700
  static const Color darkBorder = Color(0xFF475569); // Slate 600
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Neutral Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
}
