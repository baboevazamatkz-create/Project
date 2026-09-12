import 'package:flutter/material.dart';

/// A warm, muted graphite -- the ink tone the whole palette is built around.
/// Never pure black: a touch of warmth keeps it from reading cold or cheap.
const Color kAccentColor = Color(0xFF2B2622);

/// Semantic colours shared across the whole app, so income, expenses and the
/// brand accent look identical everywhere they appear. Deliberately muted --
/// a saturated green/red reads as a consumer app; desaturating them (and the
/// brand accent, a muted bronze rather than a bright green) is what makes the
/// palette read as calm and premium instead.
const Color kIncomeColor = Color(0xFF5C8567);
const Color kExpenseColor = Color(0xFFB15D4E);
const Color kBrandColor = Color(0xFFAD8B5C);

/// The warm tone the background pattern is drawn in. It is always used at a
/// very low opacity — the pattern should read as texture, never as content.
/// Shares the brand's bronze rather than a separate bright accent, so the
/// texture feels like part of the same material instead of a sticker on it.
const Color kPatternColor = Color(0xFFAD8B5C);

/// [kAccentColor] is a near-black ink tone: right on the light theme, and
/// invisible on the dark one. Anything that paints the accent *on* the
/// background — an icon, a tint, a hairline — has to flip with the theme,
/// so it reads on both.
Color accentForeground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : kAccentColor;

/// The hairline that outlines a card's glass edge and separates rows from
/// each other -- a touch stronger in dark mode, where the same alpha over a
/// near-black surface all but disappears.
Color _hairlineFor(bool isDark) => (isDark ? Colors.white : kAccentColor)
    .withValues(alpha: isDark ? 0.14 : 0.10);

Color hairlineColor(BuildContext context) =>
    _hairlineFor(Theme.of(context).brightness == Brightness.dark);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kAccentColor,
    brightness: brightness,
    primary: kAccentColor,
  );
  final hairline = _hairlineFor(isDark);
  // A soft, warm-tinted shadow rather than Material's default cool grey --
  // barely visible, just enough to lift a card off the page.
  final cardShadow = kAccentColor.withValues(alpha: isDark ? 0.35 : 0.10);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF17161A) : const Color(0xFFF6F2EC),
    appBarTheme: AppBarTheme(
      backgroundColor:
          isDark ? const Color(0xFF17161A) : const Color(0xFFF6F2EC),
      foregroundColor: isDark ? Colors.white : kAccentColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : kAccentColor,
        fontSize: 22,
        fontWeight: FontWeight.normal,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kAccentColor,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: cardShadow,
      surfaceTintColor: Colors.transparent,
      color: isDark ? const Color(0xFF201F23) : const Color(0xFFFEFCF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: hairline, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme:
        Typography.material2021(platform: TargetPlatform.android).black.apply(
              bodyColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
              displayColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
    dividerTheme: DividerThemeData(
      color: hairline,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF232227) : const Color(0xFFF1ECE3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: (isDark ? Colors.white : const Color(0xFF1A1A1A))
            .withValues(alpha: 0.32),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
