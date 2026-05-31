import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:habit_mood_journal/main.dart';
import 'package:habit_mood_journal/providers/theme_provider.dart';

void main() {
  setUpAll(() {
    // Initialize FFI-based SQLite for testing (native plugin not available)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Prevent google_fonts from making network requests during tests.
    // When the font isn't available locally, it falls back to the system font.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Provide mock initial values for SharedPreferences so that
    // ReminderProvider.loadSettings() completes without hanging.
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    // Mock path_provider MethodChannel so getApplicationDocumentsDirectory()
    // returns a valid temp path instead of hanging in the fake async zone.
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  tearDown(() {
    // Remove the mock handler after each test
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  testWidgets('App loads successfully', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(MovoApp(themeProvider: themeProvider));

    // The app starts with a SplashScreen. Verifying the splash screen renders
    // confirms the app builds and initialises without crashing.
    expect(find.text('Movo'), findsOneWidget);

    // Pump through the splash screen's async lifecycle to clear all
    // pending timers and avoid teardown errors.
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}
