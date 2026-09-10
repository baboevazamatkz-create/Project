import 'package:intl/intl.dart';

enum AppCurrency { rub, kzt, usd }

final _formatCache = <AppCurrency, NumberFormat>{};

extension AppCurrencyX on AppCurrency {
  String get symbol {
    switch (this) {
      case AppCurrency.rub:
        return '₽';
      case AppCurrency.kzt:
        return '₸';
      case AppCurrency.usd:
        return '\$';
    }
  }

  String get locale {
    switch (this) {
      case AppCurrency.rub:
        return 'ru';
      case AppCurrency.kzt:
        return 'kk';
      case AppCurrency.usd:
        return 'en_US';
    }
  }

  String get label {
    switch (this) {
      case AppCurrency.rub:
        return 'Рубль';
      case AppCurrency.kzt:
        return 'Тенге';
      case AppCurrency.usd:
        return 'Доллар';
    }
  }

  /// Cached per currency: building a [NumberFormat] parses locale data, and
  /// this is read for every amount on screen on every rebuild.
  NumberFormat get format => _formatCache.putIfAbsent(
        this,
        () => NumberFormat.currency(
          locale: locale,
          symbol: symbol,
          decimalDigits: 0,
        ),
      );

  String get storageKey => name;

  static AppCurrency fromStorageKey(String? key) {
    return AppCurrency.values.firstWhere(
      (c) => c.name == key,
      orElse: () => AppCurrency.rub,
    );
  }
}

/// Fixed, hand-set average exchange rates for the currency-view toggle
/// (see HomeScreen). These are deliberately NOT live rates: the toggle is
/// for a rough "what would this be in..." glance at a budget, not anything
/// that has to be exact, and a live-rate dependency would need network
/// access and a place to cache/refresh it for no real benefit here.
/// Expressed as "how many RUB is 1 unit of this currency worth"; update
/// occasionally, nothing else depends on the exact figures.
const Map<AppCurrency, double> _approxRubValue = {
  AppCurrency.rub: 1,
  AppCurrency.kzt: 1 / 5.3,
  AppCurrency.usd: 86,
};

/// Converts [amount] from [from] to [to] using the fixed average rates
/// above, pivoting through RUB. Same-currency conversion is exact and
/// returns [amount] unchanged; anything else is an approximation, and
/// callers should mark the result as such in the UI (see
/// SummaryCard.isApproximate / ExpenseTile.isApproximate).
double convertApprox(
  double amount, {
  required AppCurrency from,
  required AppCurrency to,
}) {
  if (from == to) return amount;
  final inRub = amount * _approxRubValue[from]!;
  return inRub / _approxRubValue[to]!;
}
