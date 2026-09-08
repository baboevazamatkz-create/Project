import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency.dart';

class SettingsRepository {
  static const _lastCurrencyKey = 'last_currency';

  Future<AppCurrency> loadLastCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return AppCurrencyX.fromStorageKey(prefs.getString(_lastCurrencyKey));
  }

  Future<void> saveLastCurrency(AppCurrency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCurrencyKey, currency.storageKey);
  }
}
