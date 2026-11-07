  import 'package:flutter/material.dart';

class AppColors {
  static const charcoal = Color(0xFF0E1117);
  static const charcoalSurface = Color(0xFF161B24);
  static const electricBlue = Color(0xFF2F6BFF);
  static const neonCyan = Color(0xFF22E5FF);
  static const purple = Color(0xFF8B5CF6);
  static const magenta = Color(0xFFE040FB);
  static const orange = Color(0xFFFF9F43);
  static const errorRed = Color(0xFFFF4D6D);
  static const success = Color(0xFF2EE59D);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricBlue, purple, magenta],
  );
}