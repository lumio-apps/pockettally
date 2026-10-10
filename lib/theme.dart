import 'package:flutter/material.dart';

/// PocketTally brand colors (from the "Pocket In/Out" logo).
const Color kBrand = Color(0xFF0E3B30);
const Color kBrandSoft = Color(0xFF164A3D);
const Color kAccent = Color(0xFFF2B33D);
const Color kMint = Color(0xFF7BE0B5);

/// Chart colors that differ in lightness, not only hue.
const Color kChartIncome = Color(0xFF1F7A63);
const Color kChartExpense = Color(0xFFF2B33D);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: brightness,
  ).copyWith(
    primary: dark ? kMint : kBrand,
    onPrimary: dark ? kBrand : Colors.white,
    secondary: kAccent,
    surface: dark ? const Color(0xFF13221D) : Colors.white,
  );
  final background = dark ? const Color(0xFF0B1714) : const Color(0xFFF3F6F4);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
