import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the app is in, and the switch on the home screen that flips
/// it. A plain global notifier rather than an inherited widget: the toggle
/// sits in the app bar and the [MaterialApp] that reads it is five widgets
/// up, and threading a callback through every screen in between to carry
/// one boolean would be the more complicated answer, not the simpler one.
class ThemeModeController {
  ThemeModeController._();

  static const _storageKey = 'theme_mode';

  /// [ThemeMode.system] until the user picks a side, after which their
  /// choice is remembered across launches.
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_storageKey)) {
      case 'light':
        mode.value = ThemeMode.light;
      case 'dark':
        mode.value = ThemeMode.dark;
      default:
        mode.value = ThemeMode.system;
    }
  }

  /// Flips to the opposite of what is currently *on screen*, which is not
  /// always the opposite of [mode]: while it is still following the system,
  /// the first tap has to invert whatever the system happens to be showing.
  static Future<void> toggle(BuildContext context) async {
    final next = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, next == ThemeMode.dark ? 'dark' : 'light');
  }
}
