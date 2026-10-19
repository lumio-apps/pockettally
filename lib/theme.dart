import 'package:flutter/material.dart';

import 'widgets/neo.dart';

/// PocketTally brand colors (from the "Pocket In/Out" logo).
const Color kBrand = Color(0xFF0E3B30);
const Color kBrandSoft = Color(0xFF164A3D);
const Color kAccent = Color(0xFFF2B33D);
const Color kMint = Color(0xFF7BE0B5);

/// Chart colors that differ in lightness, not only hue.
const Color kChartIncome = Color(0xFF1F7A63);
const Color kChartExpense = Color(0xFFF2B33D);

/// A color theme the user can pick in Settings ("Accent color").
/// The amber highlight stays the same in every palette.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.brand,
    required this.brandSoft,
    required this.label,
    required this.light,
    this.pageLight = const Color(0xFFF3F6F4),
    this.pageDark = const Color(0xFF0B1714),
    this.surfaceDark = const Color(0xFF13221D),
  });

  final String id;
  final String name;

  /// Deep main color: balance card, add button, avatar.
  final Color brand;

  /// Slightly lighter, for tiles on top of [brand].
  final Color brandSoft;

  /// Small text on top of [brand].
  final Color label;

  /// Main color in dark mode.
  final Color light;

  /// Page backgrounds and the dark card color, lightly tinted.
  final Color pageLight;
  final Color pageDark;
  final Color surfaceDark;
}

/// The first palette is the default for everyone who never picked one.
const List<AppPalette> kPalettes = [
  AppPalette(
    id: 'blue',
    name: 'Blue',
    brand: Color(0xFF1565FF),
    brandSoft: Color(0xFF3D7FFF),
    label: Color(0xFFDCE7FF),
    light: Color(0xFF8CB4FF),
    pageLight: Color(0xFFF5F8FD),
    pageDark: Color(0xFF0B1220),
    surfaceDark: Color(0xFF141D2E),
  ),
  AppPalette(
    id: 'forest',
    name: 'Forest',
    brand: kBrand,
    brandSoft: kBrandSoft,
    label: Color(0xFFA9DCC8),
    light: kMint,
  ),
  AppPalette(
    id: 'ocean',
    name: 'Ocean',
    brand: Color(0xFF0F2F57),
    brandSoft: Color(0xFF1B4473),
    label: Color(0xFFB3CBE8),
    light: Color(0xFF8CC8FF),
  ),
  AppPalette(
    id: 'plum',
    name: 'Plum',
    brand: Color(0xFF3B1F5E),
    brandSoft: Color(0xFF4D2D75),
    label: Color(0xFFCDBBE6),
    light: Color(0xFFD6BCFF),
  ),
  AppPalette(
    id: 'wine',
    name: 'Wine',
    brand: Color(0xFF5A1730),
    brandSoft: Color(0xFF702540),
    label: Color(0xFFEBBDCB),
    light: Color(0xFFFFB3C8),
  ),
  AppPalette(
    id: 'graphite',
    name: 'Graphite',
    brand: Color(0xFF1F2933),
    brandSoft: Color(0xFF303D49),
    label: Color(0xFFBAC6D1),
    light: Color(0xFFB8CCE0),
  ),
];

AppPalette paletteById(String? id) =>
    kPalettes.firstWhere((p) => p.id == id, orElse: () => kPalettes.first);

/// Gives widgets the current palette: `BrandColors.of(context).brand`.
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors(this.palette);

  final AppPalette palette;

  Color get brand => palette.brand;
  Color get brandSoft => palette.brandSoft;
  Color get label => palette.label;

  static BrandColors of(BuildContext context) =>
      Theme.of(context).extension<BrandColors>() ??
      BrandColors(kPalettes.first);

  @override
  BrandColors copyWith({AppPalette? palette}) =>
      BrandColors(palette ?? this.palette);

  @override
  BrandColors lerp(BrandColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

ThemeData buildTheme(Brightness brightness, [AppPalette? palette]) {
  final p = palette ?? kPalettes.first;
  final dark = brightness == Brightness.dark;
  final neo = NeoPalette.from(p, brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.brand,
    brightness: brightness,
  ).copyWith(
    primary: dark ? p.light : p.brand,
    onPrimary: dark ? p.brand : Colors.white,
    secondary: kAccent,
    surface: neo.base,
  );
  final background = neo.base;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Neumorphic look: one soft surface color everywhere (see neo.dart).
    scaffoldBackgroundColor: background,
    canvasColor: background,
    extensions: [BrandColors(p)],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: neo.base,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: neo.base,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: neo.base,
      surfaceTintColor: Colors.transparent,
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
    // Smooth, light page changes on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: NeoPageTransitionsBuilder(),
      TargetPlatform.windows: NeoPageTransitionsBuilder(),
      TargetPlatform.linux: NeoPageTransitionsBuilder(),
      TargetPlatform.iOS: NeoPageTransitionsBuilder(),
      TargetPlatform.macOS: NeoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: NeoPageTransitionsBuilder(),
    }),
  );
}
