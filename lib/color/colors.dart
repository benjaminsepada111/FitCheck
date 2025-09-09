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

  // Secondary Swatch
  // Secondary Swatch (green gradient based)
  static const MaterialColor secondary = MaterialColor(
    0xFF018053, // base
    <int, Color>{
      50: Color(0xFFE0F4ED),
      100: Color(0xFFB3E2D0),
      200: Color(0xFF80CDB0),
      300: Color(0xFF4DB790),
      400: Color(0xFF26A678),
      500: Color(0xFF018053), // base
      600: Color(0xFF01734B),
      700: Color(0xFF016643),
      800: Color(0xFF01583A),
      900: Color(0xFF01432A),
    },
  );


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
