import 'package:flutter/material.dart';

import '../theme.dart';

/// The bar under [SummaryCard]: the totals card states what happened, this
/// is the one thing on that screen offering to explain it.
///
/// Built to read as the summary card's own edge rather than a separate
/// control -- same rim gradient, same corner radius, same shadow -- so the
/// two read as one object rather than a card and a stray button under it.
/// Full width and a fixed height of its own, so it drops into a plain
/// Column the same way SummaryCard does, with no shared-height trick
/// between the two needed.
class AdviceTabButton extends StatelessWidget {
  final VoidCallback onTap;

  const AdviceTabButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            goldFor(context).withValues(alpha: 0.62),
            goldFor(context).withValues(alpha: 0.20),
            goldFor(context).withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.34 : 0.12,
            ),
            blurRadius: 34,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: heroGradientFor(context)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: goldFor(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Советы по расходам',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: heroForeground(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ИИ разберёт траты и подскажет, на чём сэкономить',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: heroForeground(context)
                                  .withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: heroForeground(context).withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
