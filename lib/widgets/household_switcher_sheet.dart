import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/currency.dart';
import '../models/household.dart';
import '../theme.dart';
import 'currency_symbol_icon.dart';

/// Everything in this sheet is drawn at this fraction of its usual size,
/// the same one-factor approach the add sheet uses.
const double _kScale = 1 / 1.2;

double _s(double value) => value * _kScale;

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
    // The rows and the add button take their metrics from the app theme,
    // so scaling only the figures written here would close the gaps and
    // leave the controls full height. This override scales them too, and
    // stops at this sheet.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        iconTheme: theme.iconTheme.copyWith(size: _s(24)),
        iconButtonTheme: IconButtonThemeData(
          style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
            padding: WidgetStatePropertyAll(EdgeInsets.all(_s(8))),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(_s(20), _s(20), _s(20), _s(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: _s(38),
                  height: _s(4),
                  margin: EdgeInsets.only(bottom: _s(22)),
                  decoration: BoxDecoration(
                    color: accentForeground(context).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(_s(2)),
                  ),
                ),
              ),
              Text(
                'МОИ БЮДЖЕТЫ',
                style: microLabel(
                  context,
                  size: _s(11),
                  color: goldFor(context).withValues(alpha: 0.9),
                ),
              ),
              SizedBox(height: _s(18)),
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
              SizedBox(height: _s(12)),
              SizedBox(
                height: _s(52),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldFor(context),
                    side: BorderSide(
                      color: goldFor(context).withValues(alpha: 0.45),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: _s(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_s(14)),
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: _s(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAddHousehold();
                  },
                  icon: Icon(Icons.add_circle_outline, size: _s(24)),
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
      padding: EdgeInsets.only(bottom: _s(10)),
      child: Material(
        color: isActive
            ? goldFor(context).withValues(alpha: 0.10)
            : accentForeground(context).withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(_s(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_s(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_s(16)),
              border: Border.all(
                color: isActive
                    ? goldFor(context).withValues(alpha: 0.45)
                    : hairlineColor(context),
              ),
            ),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: _s(16), vertical: _s(14)),
              child: Row(
                children: [
                  Container(
                    width: _s(40),
                    height: _s(40),
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
                      size: _s(19),
                    ),
                  ),
                  SizedBox(width: _s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          household.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _s(15),
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                        SizedBox(height: _s(3)),
                        Text(
                          household.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _s(11),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.4,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The check marks the open budget; copying its code is
                  // just as useful there as on any other row, so the button
                  // stays and the check sits to the left of it.
                  if (isActive)
                    Padding(
                      padding: EdgeInsets.only(right: _s(2)),
                      child: Icon(Icons.check_circle_rounded,
                          color: goldFor(context), size: _s(20)),
                    ),
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
                    icon: Icon(Icons.copy_rounded, size: _s(18)),
                    tooltip: 'Скопировать код',
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
