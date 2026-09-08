import 'package:intl/intl.dart';

enum AppCurrency { rub, kzt, usd }

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

  NumberFormat get format =>
      NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);

  String get storageKey => name;

  static AppCurrency fromStorageKey(String? key) {
    return AppCurrency.values.firstWhere(
      (c) => c.name == key,
      orElse: () => AppCurrency.rub,
    );
  }
}
