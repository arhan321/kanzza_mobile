import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryColor = Color(0xFF7132F5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      scaffoldBackgroundColor: const Color(0xFFF8F9FD),

      primaryColor: primaryColor,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(),
        bodyMedium: GoogleFonts.inter(),
      ),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(
            double.infinity,
            56,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme:
          InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,

        hintStyle: GoogleFonts.inter(
          color: Colors.grey,
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(24),
        ),
      ),

      navigationBarTheme:
          NavigationBarThemeData(
        backgroundColor: Colors.white,

        indicatorColor:
            primaryColor.withOpacity(.12),

        labelTextStyle:
            WidgetStateProperty.all(
          GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}