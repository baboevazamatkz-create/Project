import 'package:flutter/material.dart';

/// The scanner's mark: a capture frame with a spark inside it.
///
/// The plain document icon said "scan" and nothing about what does the
/// reading. Letters -- an "AI" set inside a square -- were the other
/// option and were rejected: three characters at ten pixels inside a forty
/// pixel button read as noise, and type this small fights everything else
/// on the screen. The spark is the one symbol that needs no translation,
/// and the frame keeps the meaning "point this at something".
class AiScanIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const AiScanIcon({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.crop_free_rounded, size: size, color: ink),
          // Just over half: large enough to read as a spark rather than a
          // speck, small enough to keep clear of the frame's corners.
          Icon(Icons.auto_awesome_rounded, size: size * 0.56, color: ink),
        ],
      ),
    );
  }
}
