import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _followSystem = true;
  bool _manualDarkMode = false;
  Brightness _systemBrightness = Brightness.light;

  /// The effective dark mode state.
  /// When following the system, returns the system brightness.
  /// In manual mode, returns the manual preference.
  bool get isDarkMode =>
      _followSystem
          ? _systemBrightness == Brightness.dark
          : _manualDarkMode;

  /// Whether the app should follow the system brightness.
  bool get followSystem => _followSystem;

  /// Update the system brightness (called from the widget tree observer).
  void updateSystemBrightness(Brightness brightness) {
    _systemBrightness = brightness;
    notifyListeners();
  }

  /// Toggle theme mode.
  /// If currently following system, switches to manual mode with the
  /// opposite of the current effective theme.
  /// If in manual mode, toggles between light/dark.
  Future<void> toggleTheme() async {
    if (_followSystem) {
      // Switch to manual mode, opposite of current system theme
      _followSystem = false;
      _manualDarkMode = _systemBrightness != Brightness.dark;
    } else {
      // Toggle manual mode
      _manualDarkMode = !_manualDarkMode;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('follow_system', _followSystem);
    await prefs.setBool('is_dark_mode', _manualDarkMode);
    notifyListeners();
  }

  /// Switch to follow-system mode.
  Future<void> enableFollowSystem() async {
    _followSystem = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('follow_system', true);
    notifyListeners();
  }

  /// Set manual dark mode (disables follow-system).
  Future<void> setDarkMode(bool value) async {
    _followSystem = false;
    _manualDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('follow_system', false);
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  /// Load persisted theme preferences.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _followSystem = prefs.getBool('follow_system') ?? true;
    _manualDarkMode = prefs.getBool('is_dark_mode') ?? false;
    // Initialize with the actual system brightness to avoid a flash on first launch
    _systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    notifyListeners();
  }
}
