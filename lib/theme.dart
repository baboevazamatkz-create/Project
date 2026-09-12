import 'package:flutter/material.dart';

/// The palette is built as two matched rooms rather than one set of colours
/// with a switch: "Ivory" (light) is warm paper, "Obsidian" (dark) is deep
/// warm black. Both share the same champagne accent, which is what carries
/// the premium feel -- a metallic tone reads as expensive where a saturated
/// brand colour reads as an app store icon.

/// Rich, warm near-black -- the ink everything is written in on Ivory, and
/// the material the hero card is cut from in both themes.
const Color kAccentColor = Color(0xFF1B1813);

/// Champagne. Deep enough to stay legible as text on paper, and the same
/// family as [kChampagne], which is the version used on dark surfaces.
const Color kGoldDeep = Color(0xFF9A7B44);
const Color kChampagne = Color(0xFFC8A86B);

/// Money colours, deliberately desaturated: a jewel-toned emerald and a
/// muted terracotta rather than traffic-light green and red.
const Color kIncomeColor = Color(0xFF44705B);
const Color kExpenseColor = Color(0xFFA4534A);

/// Their dark-theme counterparts -- the same hues lifted, because a deep
/// jewel tone goes muddy against near-black.
const Color kIncomeColorDark = Color(0xFF6FA083);
const Color kExpenseColorDark = Color(0xFFC07D6C);

/// Kept as the app's single "brand" hook (buttons, rings, active states)
/// so widgets that want the accent don't each pick their own gold.
const Color kBrandColor = kGoldDeep;

/// The tone the background texture is drawn in — always at a very low
/// opacity. It should read as the grain of the paper, never as content.
const Color kPatternColor = kChampagne;

const _ivoryTop = Color(0xFFF6F2EA);
const _ivoryBottom = Color(0xFFEDE6DA);
const _obsidianTop = Color(0xFF141318);
const _obsidianBottom = Color(0xFF0C0C0F);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// [kAccentColor] is a near-black ink tone: right on Ivory, invisible on
/// Obsidian. Anything that paints the accent *on* the background — an icon,
/// a tint, a hairline — has to flip with the theme so it reads on both.
Color accentForeground(BuildContext context) =>
    _isDark(context) ? const Color(0xFFF2EFE9) : kAccentColor;

/// The champagne at the weight that survives the current background: deeper
/// on paper, lighter on black.
Color goldFor(BuildContext context) =>
    _isDark(context) ? kChampagne : kGoldDeep;

Color incomeColor(BuildContext context) =>
    _isDark(context) ? kIncomeColorDark : kIncomeColor;

Color expenseColor(BuildContext context) =>
    _isDark(context) ? kExpenseColorDark : kExpenseColor;

/// The hairline that draws a surface's edge. Everything is separated by one
/// of these rather than by a heavy border or a filled divider.
Color _hairlineFor(bool isDark) => (isDark ? Colors.white : kAccentColor)
    .withValues(alpha: isDark ? 0.10 : 0.09);

Color hairlineColor(BuildContext context) => _hairlineFor(_isDark(context));

/// The page itself is a soft vertical wash rather than one flat fill —
/// the cheapest way to stop a screen looking like a default template.
LinearGradient pageGradient(BuildContext context) {
  final isDark = _isDark(context);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? const [_obsidianTop, _obsidianBottom]
        : const [_ivoryTop, _ivoryBottom],
  );
}

/// The hero card is obsidian in *both* themes: a dark, faintly metallic
/// panel on ivory paper is the single strongest "this is expensive" cue the
/// screen has, and on Obsidian it simply reads as a raised slab.
///
/// It is translucent, and frosts what is behind it -- enough for the page's
/// light and grain to come through the glass, not so much that white text
/// on it stops being white text on something dark.
LinearGradient heroGradientFor(BuildContext context) {
  final alpha = _isDark(context) ? 0.72 : 0.80;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF2A2831).withValues(alpha: alpha - 0.06),
      const Color(0xFF171620).withValues(alpha: alpha),
      const Color(0xFF101014).withValues(alpha: alpha),
    ],
    stops: const [0.0, 0.55, 1.0],
  );
}

/// Text sitting on the hero card, which is dark regardless of theme.
const Color kOnHero = Color(0xFFF4F1EA);

/// The body of a pane of glass: one even translucent fill. It used to be a
/// gradient, which on a list of rows read as each row being lit from its own
/// corner -- busy, and the thing that made the list look tilted.
Color glassFill(BuildContext context) => _isDark(context)
    ? Colors.white.withValues(alpha: 0.055)
    : Colors.white.withValues(alpha: 0.58);

/// The lit edge around it: bright where the light lands, nearly gone on the
/// far side. This one gradient is most of what separates glass from a
/// rounded rectangle with an outline.
LinearGradient glassEdgeGradient(BuildContext context) {
  final isDark = _isDark(context);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ]
        : [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.45),
            kAccentColor.withValues(alpha: 0.12),
          ],
    stops: const [0.0, 0.45, 1.0],
  );
}

/// A sheet is a bigger, calmer pane than a row: same material, less of a
/// gradient, so long content does not sit on a visible ramp.
LinearGradient sheetBodyGradient(BuildContext context) {
  final isDark = _isDark(context);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [
            const Color(0xFF24232B).withValues(alpha: 0.74),
            const Color(0xFF16151B).withValues(alpha: 0.82)
          ]
        : [
            Colors.white.withValues(alpha: 0.72),
            const Color(0xFFF7F3EC).withValues(alpha: 0.80)
          ],
  );
}

/// The app bar floats over the scrolling list, so it is the one surface
/// that genuinely needs frosting rather than translucency alone.
Color appBarGlassTint(BuildContext context) => _isDark(context)
    ? const Color(0xFF141318).withValues(alpha: 0.58)
    : const Color(0xFFF6F2EA).withValues(alpha: 0.62);

/// Small, letterspaced, uppercase — the label style that does most of the
/// work in making a layout feel considered rather than default.
TextStyle microLabel(BuildContext context,
        {Color? color, double size = 10.5}) =>
    TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.3,
      color: color ?? accentForeground(context).withValues(alpha: 0.45),
    );

/// Figures are always tabular: money that shifts sideways as the digits
/// change is the detail that gives a finance app away.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

TextStyle moneyStyle({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = -0.2,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: kTabularFigures,
    );

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final ink = isDark ? const Color(0xFFF2EFE9) : kAccentColor;
  final hairline = _hairlineFor(isDark);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kGoldDeep,
    brightness: brightness,
    primary: isDark ? kChampagne : kGoldDeep,
    surface: isDark ? const Color(0xFF16151B) : const Color(0xFFFCFAF6),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'Onest',
    // Matches the top of the page gradient the body paints, so the strip
    // behind the (transparent) app bar continues it seamlessly.
    scaffoldBackgroundColor: isDark ? _obsidianTop : _ivoryTop,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Onest',
        color: ink,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: ink.withValues(alpha: 0.78), size: 21),
      actionsIconTheme:
          IconThemeData(color: ink.withValues(alpha: 0.78), size: 21),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? kChampagne : kAccentColor,
      foregroundColor: isDark ? kAccentColor : const Color(0xFFF6F2EA),
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 6,
      shape: const CircleBorder(),
    ),
    // Icons sit tighter than Material's default 48pt tap slabs: five of them
    // at full width left the app bar title truncated on a phone.
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(5),
        minimumSize: const Size(34, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      // Already translucent: rows are glass over the page wash, and the
      // grain behind them should stay faintly visible through the stack.
      color: (isDark ? const Color(0xFF1F1E26) : Colors.white)
          .withValues(alpha: isDark ? 0.55 : 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: hairline, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(fontFamily: 'Onest', bodyColor: ink, displayColor: ink),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: (isDark ? Colors.white : kAccentColor)
          .withValues(alpha: isDark ? 0.05 : 0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: hairline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: hairline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: (isDark ? kChampagne : kGoldDeep).withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: TextStyle(color: ink.withValues(alpha: 0.32)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Champagne on black, obsidian on paper: in both cases the primary
        // action is the one solid, confident block on the screen.
        backgroundColor: isDark ? kChampagne : kAccentColor,
        foregroundColor: isDark ? kAccentColor : const Color(0xFFF6F2EA),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 17),
        textStyle: const TextStyle(
          fontFamily: 'Onest',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink.withValues(alpha: 0.7),
        textStyle: const TextStyle(
          fontFamily: 'Onest',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor:
          isDark ? const Color(0xFF16151B) : const Color(0xFFFBF8F2),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor:
          isDark ? const Color(0xFF1B1A21) : const Color(0xFFFBF8F2),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: hairline, width: 1),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Onest',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Onest',
        fontSize: 14,
        color: ink.withValues(alpha: 0.7),
        height: 1.4,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? const Color(0xFF26242D) : kAccentColor,
      contentTextStyle: const TextStyle(
        fontFamily: 'Onest',
        color: Color(0xFFF2EFE9),
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
