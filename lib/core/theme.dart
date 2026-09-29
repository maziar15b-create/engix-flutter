import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg0 = Color(0xFF02060E);
  static const bg1 = Color(0xFF0A0E18);
  static const bg2 = Color(0xFF12151F);
  static const bg3 = Color(0xFF1A1E2C);
  static const red = Color(0xFFC50337);
  static const redLight = Color(0xFFFF3D63);
  static const redDeep = Color(0xFF7A0224);
  static const line = Color(0x47C50337);
  static const text = Color(0xFFF5F4FA);
  static const muted = Color(0xFF6B7085);
  static const soft = Color(0xFF94A3B8);
  static const danger = Color(0xFFE5484D);
  static const online = Color(0xFF2ED573);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0x33C50337)),
  );
  return base.copyWith(
    scaffoldBackgroundColor: C.bg0,
    colorScheme: const ColorScheme.dark(
      primary: C.red,
      secondary: C.redLight,
      surface: C.bg2,
      error: C.danger,
    ),
    textTheme: GoogleFonts.vazirmatnTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.bg1,
      hintStyle: const TextStyle(color: C.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: C.red, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.bg1,
      indicatorColor: const Color(0x33C50337),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
