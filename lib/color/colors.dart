import 'package:flutter/material.dart';

class AppColors {
  // Primary Swatch
  static const MaterialColor primary = MaterialColor(
    0xFF06111D, // base
    <int, Color>{
      50: Color(0xFFE2E6EA),
      100: Color(0xFFB6BFC8),
      200: Color(0xFF8594A3),
      300: Color(0xFF54697E),
      400: Color(0xFF304861),
      500: Color(0xFF06111D), // base
      600: Color(0xFF05101B),
      700: Color(0xFF040E18),
      800: Color(0xFF030C14),
      900: Color(0xFF02090F),
    },
  );

  // Secondary Swatch (green gradient based)
  // Secondary Swatch (red gradient based)
  static const MaterialColor secondary = MaterialColor(
    0xFFDC2626, // base (red 600)
    <int, Color>{
      50: Color(0xFFFEF2F2),
      100: Color(0xFFFEE2E2),
      200: Color(0xFFFECACA),
      300: Color(0xFFFCA5A5),
      400: Color(0xFFF87171),
      500: Color(0xFFEF4444), // red 500
      600: Color(0xFFDC2626), // base (red 600)
      700: Color(0xFFB91C1C),
      800: Color(0xFF991B1B),
      900: Color(0xFF7F1D1D),
    },
  );
/*

static const MaterialColor secondary = MaterialColor(
  0xFF2563EB, // base (blue 600)
  <int, Color>{
    50: Color(0xFFEFF6FF),
    100: Color(0xFFDBEAFE),
    200: Color(0xFFBFDBFE),
    300: Color(0xFF93C5FD),
    400: Color(0xFF60A5FA),
    500: Color(0xFF3B82F6),
    600: Color(0xFF2563EB), // base
    700: Color(0xFF1D4ED8),
    800: Color(0xFF1E40AF),
    900: Color(0xFF1E3A8A),
  },
);

 */

  // Text Colors
  static const Color textWhite = Colors.white;
  static const Color textGrey = Colors.grey;

  // Social Buttons
  static const Color googleBg = Color(0xFFEEEEEE);
  static const Color facebookBg = Color(0xFF1877F2);
  static const Color appleBg = Colors.black;

  // Additional colors
  static const Color inputBg = Color(0xFFF2F2F2);
  static const Color buttons = Color(0xFF4CAF50);
}
