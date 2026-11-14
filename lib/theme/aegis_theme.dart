import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AegisColors {
  static const Color background = Color(0xFF1A3A5C);
  static const Color primary = Color(0xFFFF5722); // Safety Orange
  static const Color primaryContainer = Color(0xFFC83A0E);
  static const Color secondary = Color(0xFF2196F3); // Trust Blue
  static const Color tertiary = Color(0xFF4CAF50); // Green / Safe
  static const Color tertiaryContainer = Color(0xFF1B5E20);
  static const Color surfaceContainerLow = Color(0xFF1E1F25);
  static const Color surfaceContainerHigh = Color(0xFF282A32);
  static const Color surfaceContainerHighest = Color(0xFF323540);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A5B5);

  // Status colours (used by safety scores, hazard pins, validation).
  static const Color warning = Color(0xFFFFB300); // Amber / Moderate
  static const Color danger = Color(0xFFE53935); // Red / Risky
  static const Color outline = Color(0xFF3D4150);

  /// Colour for a 0–100 safety score.
  static Color forScore(int score) {
    if (score >= 75) return tertiary;
    if (score >= 50) return warning;
    return danger;
  }
}

/// Spacing scale – use instead of ad-hoc numbers.
class AegisSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radius scale.
class AegisRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

/// One ThemeData for the whole app (scope §9, Member 1 Day 2 / Member 5).
class AegisTheme {
  AegisTheme._();

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: AegisColors.textPrimary,
      displayColor: AegisColors.textPrimary,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: AegisColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AegisColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AegisColors.primaryContainer,
      secondary: AegisColors.secondary,
      tertiary: AegisColors.tertiary,
      error: AegisColors.danger,
      surface: AegisColors.surfaceContainerLow,
      onSurface: AegisColors.textPrimary,
      onSurfaceVariant: AegisColors.textSecondary,
      surfaceContainerLow: AegisColors.surfaceContainerLow,
      surfaceContainerHigh: AegisColors.surfaceContainerHigh,
      surfaceContainerHighest: AegisColors.surfaceContainerHighest,
      outline: AegisColors.outline,
    );

    final roundedLg = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AegisRadius.lg));

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AegisColors.background,
      textTheme: textTheme,
      dividerColor: AegisColors.surfaceContainerHighest,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AegisColors.surfaceContainerLow,
        foregroundColor: AegisColors.textPrimary,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AegisColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AegisColors.surfaceContainerHigh,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AegisRadius.xl)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AegisColors.surfaceContainerHigh,
        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
        hintStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
        prefixIconColor: AegisColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AegisRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AegisRadius.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AegisRadius.lg),
          borderSide: const BorderSide(color: AegisColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AegisRadius.lg),
          borderSide: const BorderSide(color: AegisColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AegisRadius.lg),
          borderSide: const BorderSide(color: AegisColors.danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AegisColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AegisColors.surfaceContainerHighest,
          minimumSize: const Size(64, 48),
          shape: roundedLg,
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AegisColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: roundedLg,
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AegisColors.primary,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AegisColors.primary, width: 1.5),
          shape: roundedLg,
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AegisColors.primary,
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AegisColors.primary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AegisColors.surfaceContainerHigh,
        selectedColor: AegisColors.primary,
        labelStyle: GoogleFonts.outfit(color: AegisColors.textPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AegisColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AegisRadius.md)),
        checkmarkColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : AegisColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
            ? AegisColors.primary
            : AegisColors.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AegisColors.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.outfit(color: AegisColors.textPrimary),
        actionTextColor: AegisColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AegisRadius.md)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AegisColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AegisRadius.xl)),
        titleTextStyle: GoogleFonts.outfit(
            fontSize: 20, fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
        contentTextStyle: GoogleFonts.outfit(fontSize: 14, color: AegisColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AegisColors.surfaceContainerLow,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AegisRadius.xxl)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AegisColors.primary),
      listTileTheme: const ListTileThemeData(iconColor: AegisColors.textSecondary),
    );
  }
}
