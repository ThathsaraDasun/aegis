import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared design tokens for the Aegis Safe Walk app.
///
/// Every screen and widget should pull colours, spacing, radii, elevation and
/// text styles from here instead of defining one-off inline values.

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
  static const Color onPrimary = Colors.white;

  /// Palette used for contact / profile avatars (picked by name hash).
  static const List<Color> avatarPalette = [
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.redAccent,
    Colors.tealAccent,
    Colors.indigoAccent,
  ];

  /// Consistent avatar colour for a given name.
  static Color avatarFor(String name) =>
      avatarPalette[name.hashCode.abs() % avatarPalette.length];
}

/// Spacing scale (logical pixels). Use for padding, margins and gaps.
class AegisSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Default padding around the scrollable content of a screen.
  static const EdgeInsets screen = EdgeInsets.all(xl);

  /// Default padding for lists of cards.
  static const EdgeInsets list = EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Default inner padding for cards.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Default margin between stacked cards.
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(vertical: 6, horizontal: xs);
}

/// Corner radius scale.
class AegisRadius {
  static const double xs = 4;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const RoundedRectangleBorder mdShape = RoundedRectangleBorder(borderRadius: mdAll);
}

/// Elevation scale.
class AegisElevation {
  static const double none = 0;
  static const double low = 2;
  static const double medium = 4;
  static const double high = 8;
}

/// Shared sizes for icons and buttons.
class AegisSizes {
  static const double iconSm = 14;
  static const double iconMd = 18;
  static const double iconLg = 28;
  static const double iconXl = 64;
  static const double buttonHeight = 52;
}

/// Typography tokens. The whole app uses the Outfit typeface.
class AegisText {
  static TextStyle _base(double size, FontWeight weight, Color color, {double? letterSpacing}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Large hero numbers (e.g. compass distance).
  static TextStyle get display => _base(48, FontWeight.bold, AegisColors.textPrimary);

  /// Screen-level headings.
  static TextStyle get headline => _base(22, FontWeight.bold, AegisColors.textPrimary);

  /// Card titles.
  static TextStyle get title => _base(18, FontWeight.bold, AegisColors.textPrimary);

  /// Emphasised body text.
  static TextStyle get bodyStrong => _base(16, FontWeight.w600, AegisColors.textPrimary);

  /// Regular body text.
  static TextStyle get body => _base(14, FontWeight.normal, AegisColors.textPrimary);

  /// Secondary / supporting text.
  static TextStyle get bodySecondary => _base(14, FontWeight.normal, AegisColors.textSecondary);

  /// Small meta text (timestamps, captions).
  static TextStyle get caption => _base(13, FontWeight.normal, AegisColors.textSecondary);

  /// Tiny labels above values.
  static TextStyle get small => _base(12, FontWeight.normal, AegisColors.textSecondary);

  /// Uppercase section headers ("RECENT TRIPS").
  static TextStyle get sectionHeader =>
      _base(13, FontWeight.bold, AegisColors.textSecondary, letterSpacing: 1.2);

  /// Uppercase status chips ("COMPLETED", "RESOLVED").
  static TextStyle chip(Color color) => _base(11, FontWeight.bold, color, letterSpacing: 1.0);

  /// Button labels.
  static TextStyle get button => _base(16, FontWeight.bold, AegisColors.onPrimary);
}

/// The single [ThemeData] that powers every screen.
class AegisTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AegisColors.primary,
        brightness: Brightness.dark,
        primary: AegisColors.primary,
        secondary: AegisColors.secondary,
        tertiary: AegisColors.tertiary,
        surface: AegisColors.surfaceContainerLow,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AegisColors.background,
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AegisColors.textPrimary,
        displayColor: AegisColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AegisColors.surfaceContainerLow,
        foregroundColor: AegisColors.textPrimary,
        elevation: AegisElevation.none,
        titleTextStyle: _appBarTitle,
      ),
      cardTheme: const CardThemeData(
        color: AegisColors.surfaceContainerHigh,
        elevation: AegisElevation.low,
        margin: AegisSpacing.cardMargin,
        shape: AegisRadius.mdShape,
      ),
      dividerTheme: const DividerThemeData(
        color: AegisColors.surfaceContainerHighest,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AegisColors.primary,
          foregroundColor: AegisColors.onPrimary,
          shape: AegisRadius.mdShape,
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AegisColors.primary,
          side: const BorderSide(color: AegisColors.primary, width: 1.5),
          shape: AegisRadius.mdShape,
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AegisColors.primary,
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AegisColors.surfaceContainerHigh,
        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
        hintStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
        prefixIconColor: AegisColors.textSecondary,
        border: const OutlineInputBorder(
          borderRadius: AegisRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AegisRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AegisRadius.mdAll,
          borderSide: BorderSide(color: AegisColors.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AegisColors.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.outfit(color: AegisColors.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AegisColors.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: AegisRadius.xlAll),
        titleTextStyle: _appBarTitle,
        contentTextStyle: GoogleFonts.outfit(fontSize: 14, color: AegisColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AegisColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AegisRadius.xl)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AegisColors.primary),
    );
  }

  static TextStyle get _appBarTitle => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AegisColors.textPrimary,
      );
}
