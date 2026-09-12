import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A pane of glass: a translucent body with a lit edge, optionally frosting
/// whatever is behind it.
///
/// [blur] is deliberately off by default. Blur costs a save layer per pane,
/// and a list row's backdrop is the (already smooth) page wash -- frosting
/// it changes almost nothing on screen while multiplying that cost by the
/// number of visible rows. It is worth paying where content actually passes
/// behind the glass: the app bar and the sheets.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;

  /// A soft drop shadow under the pane. Off for rows (a list of shadows
  /// turns to mud), on for anything that should read as floating.
  final bool elevated;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 18,
    this.blur = 0,
    this.padding,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final corner = BorderRadius.circular(radius);
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corner,
        color: glassFill(context),
        border: Border.all(color: glassEdge(context)),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (blur > 0) {
      pane = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: pane,
      );
    }

    pane = ClipRRect(borderRadius: corner, child: pane);

    if (!elevated) return pane;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corner,
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.34 : 0.10,
            ),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: pane,
    );
  }
}

/// The same glass, shaped for a modal sheet: rounded at the top only, and
/// always frosted -- the screen it slides over is exactly the content that
/// should blur behind it.
class GlassSheet extends StatelessWidget {
  final Widget child;

  const GlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const corner = BorderRadius.vertical(top: Radius.circular(28));
    return ClipRRect(
      borderRadius: corner,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: corner,
            gradient: sheetBodyGradient(context),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.16
                      : 0.75,
                ),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
