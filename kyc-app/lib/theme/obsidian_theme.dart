import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ObsidianTheme {
  static const purple = Color(0xFF7C4DFF);
  static const purpleDark = Color(0xFF4A148C);
  static const purpleLight = Color(0xFFE1B0FF);
  static const black = Color(0xFF0A0A0A);
  static const cardDark = Color(0xFF1A1A1A);
  static const surface = Color(0xFF12001A);
  static const gradient = LinearGradient(
    colors: [Color(0xFF12001A), Color(0xFF2D0B4A), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      primaryColor: purple,
      // Google Fonts: Inter (body) + JetBrains Mono (monospace)
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        brightness: Brightness.dark,
        primary: purple,
        secondary: purpleDark,
        surface: cardDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F0F0F),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: purple, width: 2)),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIconColor: purple,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: purple.withOpacity(0.2))),
        elevation: 8,
      ),
      useMaterial3: true,
    );
  }

  // Helpers para uso direto
  static TextStyle get mono => GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 12);
  static TextStyle get heading => GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800);
}
