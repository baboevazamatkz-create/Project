import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/household.dart';

class HouseholdRepository {
  static const _householdsKey = 'households';
  static const _activeCodeKey = 'active_household_code';
  static const _legacyCodeKey = 'household_code';
  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateCode({int length = 8}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  Future<List<Household>> loadHouseholds() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyCode(prefs);
    final raw = prefs.getStringList(_householdsKey) ?? [];
    return raw
        .map((e) => Household.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _migrateLegacyCode(SharedPreferences prefs) async {
    final legacyCode = prefs.getString(_legacyCodeKey);
    if (legacyCode == null) return;
    final existing = prefs.getStringList(_householdsKey) ?? [];
    if (existing.isEmpty) {
      final household = Household(code: legacyCode, label: 'Мой бюджет');
      await prefs
          .setStringList(_householdsKey, [jsonEncode(household.toJson())]);
      await prefs.setString(_activeCodeKey, legacyCode);
    }
    await prefs.remove(_legacyCodeKey);
  }

  Future<void> saveHouseholds(List<Household> households) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _householdsKey,
      households.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> addHousehold(Household household) async {
    final households = await loadHouseholds();
    if (households.any((h) => h.code == household.code)) return;
    await saveHouseholds([...households, household]);
  }

  /// Drops a budget from this device's list.
  ///
  /// Local only: the budget itself lives in Firestore under its code and
  /// stays exactly as it was for everyone else in it. Coming back is a
  /// matter of joining by the same code again, which is why the code is
  /// put in front of the user before they leave.
  Future<void> removeHousehold(String code) async {
    final households = await loadHouseholds();
    await saveHouseholds(households.where((h) => h.code != code).toList());
  }

  Future<String?> loadActiveCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeCodeKey);
  }

  Future<void> setActiveCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeCodeKey, code);
  }

  /// Forgets which budget was open, for when the last one has been left.
  /// Leaving the key pointing at a budget that is gone would have the gate
  /// look for it on every launch.
  Future<void> clearActiveCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeCodeKey);
  }
}
