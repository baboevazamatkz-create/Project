import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class HouseholdRepository {
  static const _householdCodeKey = 'household_code';
  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateCode({int length = 8}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  Future<String?> loadHouseholdCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_householdCodeKey);
  }

  Future<void> saveHouseholdCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_householdCodeKey, code);
  }

  Future<void> clearHouseholdCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_householdCodeKey);
  }
}
