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

  Future<String?> loadActiveCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeCodeKey);
  }

  Future<void> setActiveCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeCodeKey, code);
  }
}
