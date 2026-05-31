import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_mood_journal/providers/theme_provider.dart';

void main() {
  late ThemeProvider provider;

  setUp(() {
    // Reset SharedPreferences mock before each test
    SharedPreferences.setMockInitialValues({});
    provider = ThemeProvider();
  });

  group('Initial state', () {
    test('defaults to follow-system mode and light mode', () {
      expect(provider.followSystem, isTrue);
      expect(provider.isDarkMode, isFalse);
    });
  });

  group('loadTheme()', () {
    testWidgets('loads default values when no prefs saved', (tester) async {
      await provider.loadTheme();
      expect(provider.followSystem, isTrue);
      // Test environment default is Brightness.light
      expect(provider.isDarkMode, isFalse);
    });

    testWidgets('loads saved follow-system=false + dark mode from prefs',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': true,
      });
      await provider.loadTheme();
      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isTrue);
    });

    testWidgets('loads saved follow-system=false + light mode from prefs',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': false,
      });
      await provider.loadTheme();
      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isFalse);
    });

    testWidgets('loads saved follow-system=true from prefs', (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': true,
        'is_dark_mode': true, // manual pref should be ignored
      });
      await provider.loadTheme();
      expect(provider.followSystem, isTrue);
      // isDarkMode returns system brightness (light in tests), not manual pref
      expect(provider.isDarkMode, isFalse);
    });
  });

  group('toggleTheme()', () {
    testWidgets('from follow-system switches to manual with opposite brightness',
        (tester) async {
      await provider.loadTheme();

      // System is light (test default), follow-system is true
      expect(provider.followSystem, isTrue);
      expect(provider.isDarkMode, isFalse);

      await provider.toggleTheme();

      // Should switch to manual dark (opposite of light system)
      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isTrue);
    });

    testWidgets('from manual mode toggles dark mode back and forth',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': false,
      });
      await provider.loadTheme();

      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isFalse);

      // Toggle on
      await provider.toggleTheme();
      expect(provider.isDarkMode, isTrue);

      // Toggle off
      await provider.toggleTheme();
      expect(provider.isDarkMode, isFalse);
    });

    testWidgets('toggleTheme from follow-system with dark system brightness',
        (tester) async {
      await provider.loadTheme();

      // Simulate dark system brightness
      provider.updateSystemBrightness(Brightness.dark);
      expect(provider.isDarkMode, isTrue);

      // Toggle: should switch to manual light (opposite of dark system)
      await provider.toggleTheme();
      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isFalse);
    });
  });

  group('enableFollowSystem()', () {
    testWidgets('resets to follow-system mode from manual dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': true,
      });
      await provider.loadTheme();

      expect(provider.followSystem, isFalse);

      await provider.enableFollowSystem();

      expect(provider.followSystem, isTrue);
      // System is light in test environment
      expect(provider.isDarkMode, isFalse);
    });

    testWidgets('resets to follow-system mode from manual light',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': false,
      });
      await provider.loadTheme();

      await provider.enableFollowSystem();

      expect(provider.followSystem, isTrue);
    });
  });

  group('setDarkMode()', () {
    testWidgets('sets manual dark mode and disables follow-system',
        (tester) async {
      await provider.loadTheme();

      await provider.setDarkMode(true);

      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isTrue);
    });

    testWidgets('sets manual light mode and disables follow-system',
        (tester) async {
      await provider.loadTheme();

      await provider.setDarkMode(false);

      expect(provider.followSystem, isFalse);
      expect(provider.isDarkMode, isFalse);
    });

    testWidgets('can toggle between dark and light via setDarkMode',
        (tester) async {
      await provider.loadTheme();

      await provider.setDarkMode(true);
      expect(provider.isDarkMode, isTrue);

      await provider.setDarkMode(false);
      expect(provider.isDarkMode, isFalse);
    });
  });

  group('updateSystemBrightness()', () {
    test('updates isDarkMode when following system', () {
      // Start default: follow-system = true, system = light
      expect(provider.isDarkMode, isFalse);

      provider.updateSystemBrightness(Brightness.dark);
      expect(provider.isDarkMode, isTrue);

      provider.updateSystemBrightness(Brightness.light);
      expect(provider.isDarkMode, isFalse);
    });

    testWidgets('does not affect isDarkMode when in manual mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': false,
      });
      await provider.loadTheme();

      expect(provider.isDarkMode, isFalse);

      // System brightness changes to dark, but we're in manual light mode
      provider.updateSystemBrightness(Brightness.dark);

      expect(provider.isDarkMode, isFalse);
    });
  });

  group('Persistence to SharedPreferences', () {
    testWidgets('toggleTheme persists follow_system and is_dark_mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await provider.loadTheme();

      await provider.toggleTheme();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('follow_system'), isFalse);
      expect(prefs.getBool('is_dark_mode'), isTrue);
    });

    testWidgets('enableFollowSystem persists follow_system', (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
        'is_dark_mode': true,
      });
      await provider.loadTheme();

      await provider.enableFollowSystem();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('follow_system'), isTrue);
    });

    testWidgets('setDarkMode persists follow_system and is_dark_mode',
        (tester) async {
      await provider.loadTheme();

      await provider.setDarkMode(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('follow_system'), isFalse);
      expect(prefs.getBool('is_dark_mode'), isTrue);
    });

    testWidgets('loadTheme reads persisted values correctly',
        (tester) async {
      // First, save values to prefs
      var prefs = await SharedPreferences.getInstance();
      await prefs.setBool('follow_system', false);
      await prefs.setBool('is_dark_mode', true);

      // Create a new provider and load the saved values
      final newProvider = ThemeProvider();
      await newProvider.loadTheme();

      expect(newProvider.followSystem, isFalse);
      expect(newProvider.isDarkMode, isTrue);
    });
  });

  group('notifyListeners', () {
    test('updateSystemBrightness notifies listeners', () {
      int notificationCount = 0;
      provider.addListener(() => notificationCount++);

      provider.updateSystemBrightness(Brightness.dark);

      expect(notificationCount, 1);
    });

    testWidgets('toggleTheme notifies listeners', (tester) async {
      await provider.loadTheme();
      int notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.toggleTheme();

      expect(notificationCount, 1);
    });

    testWidgets('enableFollowSystem notifies listeners', (tester) async {
      SharedPreferences.setMockInitialValues({
        'follow_system': false,
      });
      await provider.loadTheme();
      int notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.enableFollowSystem();

      expect(notificationCount, 1);
    });

    testWidgets('setDarkMode notifies listeners', (tester) async {
      await provider.loadTheme();
      int notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.setDarkMode(true);

      expect(notificationCount, 1);
    });
  });
}
