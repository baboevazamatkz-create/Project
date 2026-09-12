import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/currency.dart';
import '../models/household.dart';
import '../theme.dart';
import 'currency_symbol_icon.dart';

class HouseholdSwitcherSheet extends StatelessWidget {
  final List<Household> households;
  final String activeCode;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAddHousehold;

  /// Each budget's own currency, keyed by household code -- every row
  /// shows the symbol for *that* budget, chosen once when it was created,
  /// not whichever budget happens to be open right now. A code missing
  /// from the map (still loading, or an edge case) falls back to RUB.
  final Map<String, AppCurrency> currencies;

  const HouseholdSwitcherSheet({
    super.key,
    required this.households,
    required this.activeCode,
    required this.onSwitch,
    required this.onAddHousehold,
    this.currencies = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: accentForeground(context).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'МОИ БЮДЖЕТЫ',
              style: microLabel(
                context,
                size: 11,
                color: goldFor(context).withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 18),
            for (final household in households)
              _HouseholdRow(
                household: household,
                isActive: household.code == activeCode,
                currency: currencies[household.code] ?? AppCurrency.rub,
                onTap: () {
                  Navigator.of(context).pop();
                  if (household.code != activeCode) {
                    onSwitch(household.code);
                  }
                },
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldFor(context),
                  side: BorderSide(
                    color: goldFor(context).withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onAddHousehold();
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Добавить ещё один бюджет',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdRow extends StatelessWidget {
  final Household household;
  final bool isActive;
  final AppCurrency currency;
  final VoidCallback onTap;

  const _HouseholdRow({
    required this.household,
    required this.isActive,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isActive
            ? goldFor(context).withValues(alpha: 0.10)
            : accentForeground(context).withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? goldFor(context).withValues(alpha: 0.45)
                    : hairlineColor(context),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: goldFor(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: goldFor(context).withValues(alpha: 0.28),
                      ),
                    ),
                    child: CurrencySymbolIcon(
                      currency: currency,
                      color: goldFor(context),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          household.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          household.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.4,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Icon(Icons.check_circle_rounded,
                        color: goldFor(context), size: 21)
                  else
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: household.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Код скопирован')),
                        );
                      },
                      // Champagne rather than the default ink, so it sits
                      // below the active row's check in the sheet's
                      // hierarchy.
                      color: goldFor(context).withValues(alpha: 0.7),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
