// lib/core/theme/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  // Light Theme
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF9B5EFF),
      scaffoldBackgroundColor: const Color(0xFFF5F5FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF9B5EFF),
        secondary: Color(0xFF6C3BD8),
        surface: Colors.white,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1F2937),
        onError: Colors.white,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B5EFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(color: const Color(0xFF1F2937)),
        displayMedium: GoogleFonts.poppins(color: const Color(0xFF1F2937)),
        displaySmall: GoogleFonts.poppins(color: const Color(0xFF1F2937)),
        headlineMedium: GoogleFonts.poppins(color: const Color(0xFF1F2937)),
        headlineSmall: GoogleFonts.poppins(color: const Color(0xFF1F2937)),
        titleLarge: GoogleFonts.poppins(color: const Color(0xFF1F2937)),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF374151)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF4B5563)),
        bodySmall: GoogleFonts.inter(color: const Color(0xFF6B7280)),
        labelLarge: GoogleFonts.inter(color: const Color(0xFF1F2937)),
      ),
    );
  }

  // Dark Theme
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF9B5EFF),
      scaffoldBackgroundColor: const Color(0xFF0D0D12),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9B5EFF),
        secondary: Color(0xFF6C3BD8),
        surface: Color(0xFF16162A),
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFF0EAFF),
        onError: Colors.white,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF13102A),
        foregroundColor: const Color(0xFFF0EAFF),
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF16162A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E1E35)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B5EFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D2D45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D2D45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9B97B8)),
        hintStyle: const TextStyle(color: Color(0xFF5C5878)),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(color: const Color(0xFFF0EAFF)),
        displayMedium: GoogleFonts.poppins(color: const Color(0xFFF0EAFF)),
        displaySmall: GoogleFonts.poppins(color: const Color(0xFFF0EAFF)),
        headlineMedium: GoogleFonts.poppins(color: const Color(0xFFF0EAFF)),
        headlineSmall: GoogleFonts.poppins(color: const Color(0xFFF0EAFF)),
        titleLarge: GoogleFonts.poppins(color: const Color(0xFFF0EAFF)),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFFD1CCE8)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF9B97B8)),
        bodySmall: GoogleFonts.inter(color: const Color(0xFF5C5878)),
        labelLarge: GoogleFonts.inter(color: const Color(0xFFF0EAFF)),
      ),
    );
  }
}