import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency.dart';

/// Mirrors what the home-screen widget needs into SharedPreferences.
///
/// The widget records straight into Firestore from its own broadcast
/// receiver, so it has to know which budget to write to and in which
/// currency. Both are things only the app knows: the active code lives in
/// preferences already, and the currency lives in Firestore. Writing them
/// here once per launch spares the widget a network round-trip on a tap
/// that is supposed to be instant.
///
/// The keys are read natively, so their names are part of the contract
/// with SolidusWidgetProvider.kt and a test pins them.
class WidgetBridge {
  static const householdKey = 'widget_household_code';
  static const currencyKey = 'widget_currency';

  static Future<void> publish({
    required String householdCode,
    required AppCurrency currency,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(householdKey, householdCode);
    await prefs.setString(currencyKey, currency.storageKey);
  }
}
