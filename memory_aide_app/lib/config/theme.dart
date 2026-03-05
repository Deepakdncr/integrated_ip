import 'package:flutter/material.dart';

/// CareSoul app theme – clean medical theme with teal primary.
class CareSoulTheme {
  // Colors
  static const Color primary = Color(0xFF00897B); // Teal 600
  static const Color primaryLight = Color(0xFF4DB6AC); // Teal 300
  static const Color primaryDark = Color(0xFF00695C); // Teal 800
  static const Color accent = Color(0xFF80CBC4); // Teal 200
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFE53935);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA726);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primary,
        scaffoldBackgroundColor: background,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          labelStyle: const TextStyle(fontSize: 16, color: textSecondary),
          hintStyle: const TextStyle(fontSize: 16, color: textSecondary),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
          headlineMedium: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
          titleLarge: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
          titleMedium: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w500, color: textPrimary),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
