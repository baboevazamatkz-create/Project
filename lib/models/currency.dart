import 'package:intl/intl.dart';

enum AppCurrency { rub, kzt }

extension AppCurrencyX on AppCurrency {
  String get symbol {
    switch (this) {
      case AppCurrency.rub:
        return '₽';
      case AppCurrency.kzt:
        return '₸';
    }
  }

  String get locale {
    switch (this) {
      case AppCurrency.rub:
        return 'ru';
      case AppCurrency.kzt:
        return 'kk';
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
