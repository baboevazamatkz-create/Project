import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../theme.dart';

/// One step of the onboarding tour, dressed in the room it is shown in.
///
/// The tooltip used to be a white card with black text, which was fine
/// against the old palette and wrong against both of the current ones --
/// it glared on Obsidian and clashed with the paper on Ivory. It is the
/// same surface the bottom sheets use now, with champagne titles, and its
/// buttons are built per step from [context] rather than registered once:
/// the theme can be flipped from this very screen, and colours captured at
/// registration would have stayed behind.
Showcase tourStep(
  BuildContext context, {
  required GlobalKey tourKey,
  required String title,
  required String description,
  required Widget child,
  ShapeBorder targetShapeBorder = const CircleBorder(),
  bool isLast = false,
}) {
  final ink = accentForeground(context);
  final gold = goldFor(context);
  return Showcase(
    key: tourKey,
    title: title,
    titleTextStyle: TextStyle(
      fontFamily: 'Onest',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: gold,
    ),
    description: description,
    descTextStyle: TextStyle(
      fontFamily: 'Onest',
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: ink.withValues(alpha: 0.72),
    ),
    tooltipBackgroundColor: sheetSurface(context),
    overlayColor: _isDarkTheme(context) ? Colors.black : kAccentColor,
    overlayOpacity: 0.62,
    tooltipBorderRadius: BorderRadius.circular(18),
    tooltipPadding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
    targetShapeBorder: targetShapeBorder,
    targetPadding: const EdgeInsets.all(4),
    tooltipActionConfig: TooltipActionConfig(
      position: TooltipActionPosition.inside,
      alignment:
          isLast ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
      gapBetweenContentAndAction: 12,
    ),
    tooltipActions: [
      if (!isLast)
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: 'Пропустить',
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          textStyle: TextStyle(
            fontFamily: 'Onest',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ink.withValues(alpha: 0.5),
          ),
        ),
      TooltipActionButton(
        type: TooltipDefaultActionType.next,
        name: isLast ? 'Готово' : 'Далее',
        backgroundColor: gold,
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontFamily: 'Onest',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF6F2EA),
        ),
      ),
    ],
    child: child,
  );
}

bool _isDarkTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
