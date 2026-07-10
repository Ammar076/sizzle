import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for the app: colors, typography, shapes and shadows.
class AppColors {
  // Surfaces
  static const bg = Color(0xFFF7F6F2); // soft neutral paper
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFEDEBE4); // hairline dividers/borders

  // Text
  static const ink = Color(0xFF1E1F1A); // warm charcoal
  static const muted = Color(0xFF77796F); // secondary text

  // Brand
  static const primary = Color(0xFFF04E37); // ripe tomato
  static const primaryPressed = Color(0xFFD33F29);
  static const blush = Color(0xFFFCE7E1); // soft primary tint

  // Accents
  static const forest = Color(0xFF1E3A31); // deep herb green
  static const sage = Color(0xFFE7EFE8); // soft green tint
  static const honey = Color(0xFFFFB020); // ratings / highlights
}

class AppRadii {
  static const card = 24.0;
  static const input = 16.0;
  static const button = 16.0;
  static const sheet = 30.0;
}

class AppShadows {
  static List<BoxShadow> soft = const [
    BoxShadow(color: Color(0x14231A15), blurRadius: 28, offset: Offset(0, 14)),
  ];

  static List<BoxShadow> subtle = const [
    BoxShadow(color: Color(0x0F231A15), blurRadius: 16, offset: Offset(0, 8)),
  ];
}

/// Typography. Display uses Fraunces (editorial serif); body uses Plus Jakarta
/// Sans.
class AppText {
  static TextStyle display(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w700,
    double height = 1.08,
    double spacing = -0.2,
  }) {
    return GoogleFonts.getFont(
      'Fraunces',
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
    );
  }

  static TextStyle sans(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w500,
    double height = 1.4,
    double spacing = 0,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.forest,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      centerTitle: false,
      titleTextStyle: AppText.display(20, weight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: AppText.sans(15, color: AppColors.muted),
      labelStyle: AppText.sans(15, color: AppColors.muted),
      floatingLabelStyle: AppText.sans(14, color: AppColors.primary),
      prefixIconColor: AppColors.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle:
            AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppText.sans(15, weight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.forest,
      contentTextStyle: AppText.sans(15, color: Colors.white),
      actionTextColor: AppColors.honey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: AppText.display(20, weight: FontWeight.w800),
      contentTextStyle: AppText.sans(15, color: AppColors.muted, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
