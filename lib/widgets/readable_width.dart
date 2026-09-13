import 'package:flutter/material.dart';

/// Keeps a column of content at a comfortable reading width and centres it.
///
/// On a phone this changes nothing: the constraint is wider than the screen,
/// so the child still fills it. It earns its place on a tablet, in landscape
/// and in a desktop browser window, where an app laid out portrait-first
/// otherwise stretches its cards and rows into a band too wide to scan --
/// an amount at one edge and its label at the other.
class ReadableWidth extends StatelessWidget {
  /// Roughly the width of a large phone. Wide enough that nothing is ever
  /// narrower than it is today, narrow enough that a row's two ends stay
  /// in one glance.
  static const double maxWidth = 560;

  final Widget child;

  const ReadableWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
