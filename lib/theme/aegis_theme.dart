import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AegisColors {
  // ---------------------------------------------------------------------------
  // Brand palette (the only brand colours used in the app):
  //   #007FFF  Azure        – primary actions, active states
  //   #1E90FF  Dodger blue  – secondary accents, links, route A
  //   #66CCFF  Sky blue     – soft highlights, location halo, route B
  //   #F0F8FF  Alice blue   – app background
  // ---------------------------------------------------------------------------
  static const Color azure = Color(0xFF007FFF);
  static const Color dodgerBlue = Color(0xFF1E90FF);
  static const Color skyBlue = Color(0xFF66CCFF);
  static const Color aliceBlue = Color(0xFFF0F8FF);

  static const Color background = aliceBlue;
  static const Color primary = azure;
  static const Color primaryContainer = dodgerBlue;
  static const Color secondary = dodgerBlue;
  static const Color accent = skyBlue;

  // Surfaces: white cards and light tints of the palette.
  static const Color surfaceContainerLow = Colors.white;
  static const Color surfaceContainerHigh = Color(0xFFE3F2FF);
  static const Color surfaceContainerHighest = Color(0xFFCCE7FF);
  static const Color outline = Color(0xFFB3DAFF);

  // Text: deep navy so it stays readable on the light palette.
  static const Color textPrimary = Color(0xFF0B2545);
  static const Color textSecondary = Color(0xFF52708F);

  // Status colours are kept for safety meaning only (safe / caution / SOS).
  static const Color tertiary = Color(0xFF2E9E5B); // Safe
  static const Color tertiaryContainer = Color(0xFF1E7A44);
  static const Color warning = Color(0xFFE08A00); // Caution
  static const Color danger = Color(0xFFD93636); // Risk / SOS

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

/// One ThemeData for the whole app, built only from the blue brand palette.
class AegisTheme {
  AegisTheme._();

  /// Kept so older call sites keep compiling – the app now uses [light].
  @Deprecated('Use AegisTheme.light()')
  static ThemeData dark() => light();

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: AegisColors.textPrimary,
      displayColor: AegisColors.textPrimary,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: AegisColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AegisColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AegisColors.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: AegisColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AegisColors.accent,
      onSecondaryContainer: AegisColors.textPrimary,
      tertiary: AegisColors.tertiary,
      error: AegisColors.danger,
      onError: Colors.white,
      errorContainer: AegisColors.danger,
      onErrorContainer: Colors.white,
      surface: AegisColors.surfaceContainerLow,
      onSurface: AegisColors.textPrimary,
      onSurfaceVariant: AegisColors.textSecondary,
      surfaceContainerLow: AegisColors.surfaceContainerLow,
      surfaceContainerHigh: AegisColors.surfaceContainerHigh,
      surfaceContainerHighest: AegisColors.surfaceContainerHighest,
      outline: AegisColors.outline,
      outlineVariant: AegisColors.surfaceContainerHighest,
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
        backgroundColor: AegisColors.background,
        foregroundColor: AegisColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AegisColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AegisRadius.xl),
          side: const BorderSide(color: AegisColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: AegisColors.outline),
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
          disabledForegroundColor: AegisColors.textSecondary,
          elevation: 0,
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
        backgroundColor: Colors.white,
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
        backgroundColor: AegisColors.textPrimary,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
        actionTextColor: AegisColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AegisRadius.md)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
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
      iconTheme: const IconThemeData(color: AegisColors.textPrimary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AegisColors.accent.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AegisColors.primary,
        unselectedItemColor: AegisColors.textSecondary,
        elevation: 8,
      ),
    );
  }
}
