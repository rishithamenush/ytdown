import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color brandPrimary = Color(0xFF22C55E);
  static const Color brandSecondary = Color(0xFF16A34A);
  static const Color brandAccent = Color(0xFF06B6D4);

  static const Color downloadGreen = brandPrimary;
  static const Color downloadGreenDark = brandSecondary;

  static const Color darkBg = Color(0xFF07070A);
  static const Color darkSurface = Color(0xFF111116);
  static const Color darkSurfaceHigh = Color(0xFF181820);
  static const Color darkBorder = Color(0x1FFFFFFF);

  static const Color lightBg = Color(0xFFF6F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x14000000);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandPrimary, brandSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient downloadGradient = LinearGradient(
    colors: [downloadGreen, downloadGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0xFF0E0E14), Color(0xFF07070A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: brandPrimary,
      onPrimary: Colors.white,
      secondary: brandSecondary,
      onSecondary: Colors.white,
      tertiary: brandAccent,
      surface: darkSurface,
      onSurface: Colors.white,
      surfaceContainerHighest: darkSurfaceHigh,
      onSurfaceVariant: Color(0xFFB4B4C0),
      outline: darkBorder,
      error: Color(0xFFFF5577),
    );

    return _base(scheme, darkBg, darkSurface, darkBorder);
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: brandPrimary,
      onPrimary: Colors.white,
      secondary: brandSecondary,
      onSecondary: Colors.white,
      tertiary: brandAccent,
      surface: lightSurface,
      onSurface: Color(0xFF0F0F14),
      surfaceContainerHighest: Color(0xFFEFEFF4),
      onSurfaceVariant: Color(0xFF55555F),
      outline: lightBorder,
      error: Color(0xFFD92B4A),
    );

    return _base(scheme, lightBg, lightSurface, lightBorder);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color background,
    Color surface,
    Color borderColor,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final textColor = scheme.onSurface;
    final mutedColor = scheme.onSurfaceVariant;

    final baseTextTheme = TextTheme(
      displaySmall: TextStyle(
        color: textColor,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: textColor,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: textColor, fontSize: 15, height: 1.4),
      bodyMedium: TextStyle(color: textColor, fontSize: 14, height: 1.4),
      bodySmall: TextStyle(color: mutedColor, fontSize: 12.5, height: 1.35),
      labelLarge: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: mutedColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: textColor),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF15151C) : Colors.white,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: mutedColor,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: mutedColor,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1C1C24)
            : const Color(0xFFEFEFF4),
        side: BorderSide(color: borderColor),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isDark
            ? const Color(0xFF24242E)
            : const Color(0xFFE2E2EA),
        circularTrackColor: isDark
            ? const Color(0xFF24242E)
            : const Color(0xFFE2E2EA),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
        contentTextStyle: TextStyle(color: textColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
