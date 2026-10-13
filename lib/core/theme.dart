import 'package:flutter/material.dart';

/// Warm, paper-like palette with a few bold accent colours. Everything is
/// large and rounded: the users are four to six years old.
class AppColors {
  static const paper = Color(0xFFFFF8E7);
  static const paperDark = Color(0xFFF6EBD2);
  static const ink = Color(0xFF1E3A8A);
  static const inkDone = Color(0xFF15803D);
  static const guide = Color(0xFFB8B2A3);
  static const guideActive = Color(0xFFF97316);
  static const matra = Color(0xFFE11D48);
  static const baseline = Color(0xFF2563EB);
  static const midline = Color(0xFF94A3B8);
  static const seed = Color(0xFF0F766E);
  static const star = Color(0xFFF59E0B);
}

const kDisplayFont = 'BalooDa2';
const kLetterFont = 'HindSiliguri';

/// Baloo Da 2 ships as a variable font, so weight must be requested through
/// the `wght` axis as well as [FontWeight] for it to render bold everywhere.
TextStyle display({
  double size = 20,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? height,
}) {
  final w = switch (weight) {
    FontWeight.w400 => 400.0,
    FontWeight.w500 => 500.0,
    FontWeight.w600 => 600.0,
    FontWeight.w700 => 700.0,
    _ => 800.0,
  };
  return TextStyle(
    fontFamily: kDisplayFont,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', w)],
    color: color,
    height: height,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    surface: AppColors.paper,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: kDisplayFont,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: kDisplayFont,
      bodyColor: const Color(0xFF1F2937),
      displayColor: const Color(0xFF1F2937),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: const Color(0xFF1F2937),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: display(
        size: 22,
        weight: FontWeight.w700,
        color: const Color(0xFF1F2937),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: display(size: 18, weight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 2),
        textStyle: display(size: 18, weight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        textStyle: display(size: 17, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.paper,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
