import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // BRAND & EMERGENCY COLORS
  // ============================================================

  // ResQ signature cyan-blue.
  static const Color primary = Color(0xFF00D4FF);

  static const Color primaryDark = Color(0xFF0088A8);

  static const Color primaryLight = Color(0xFF67E8F9);

  // Main header color.
  static const Color headerBlue = Color(0xFF102A43);

  // Secondary technology blue.
  static const Color secondary = Color(0xFF38BDF8);

  static const Color secondaryDark = Color(0xFF0369A1);

  // Emergency warning / attention.
  static const Color accentAlert = Color(0xFFFFC857);

  // Safe / rescued.
  static const Color success = Color(0xFF35D399);

  // ============================================================
  // SEVERITY LEVELS
  // ============================================================

  static const Color severityLow = Color(0xFF35D399);

  static const Color severityMedium = Color(0xFFFFC857);

  static const Color severityHigh = Color(0xFFFF8A4C);

  static const Color severityCritical = Color(0xFFFF4D6D);

  // ============================================================
  // DARK MODE
  // ============================================================

  static const Color darkBackground = Color(0xFF06111F);

  static const Color darkSurface = Color(0xFF0D1B2A);

  static const Color darkCard = Color(0xFF152A3D);

  // ============================================================
  // LIGHT MODE
  // ============================================================

  static const Color lightBackground = Color(0xFFF5F9FC);

  static const Color lightSurface = Color(0xFFFFFFFF);

  static const Color lightCard = Color(0xFFFFFFFF);

  static const Color lightBorder = Color(0xFFD9E5EF);

  // ============================================================
  // MESH NETWORK STATUS
  // ============================================================

  static const Color bleActive = Color(0xFF22D3EE);

  static const Color wifiDirectActive = Color(0xFFA78BFA);

  static const Color meshConnected = Color(0xFF35D399);

  static const Color meshSearching = Color(0xFFFFC857);

  // ============================================================
  // GLASSMORPHISM
  // ============================================================

  static const Color glassBorder = Color(0x33FFFFFF);

  static const Color glassFill = Color(0x14FFFFFF);
}
