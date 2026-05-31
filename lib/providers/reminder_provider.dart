import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/workmanager_service.dart';
import '../services/random_notification_service.dart';
import '../services/database_service.dart';
import '../models/habit.dart';

class ReminderProvider extends ChangeNotifier {
  static const String _keyEnabled = 'random_notif_enabled';
  static const String _keyWeeklyEnabled = 'weekly_summary_enabled';

  bool _isEnabled = false;
  bool _weeklyEnabled = true;

  final _settingsLoaded = Future<void>(() {});

  /// A Future that completes when settings have been loaded from storage.
  Future<void> get settingsLoaded => _settingsLoaded;

  bool get isEnabled => _isEnabled;
  bool get weeklyEnabled => _weeklyEnabled;

  /// Request notification permissions from the system.
  Future<void> requestPermissions() async {
    await NotificationService.instance.requestPermissions();
  }

  /// Load reminder settings from SharedPreferences.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_keyEnabled) ?? false;
      _weeklyEnabled = prefs.getBool(_keyWeeklyEnabled) ?? true;
    } catch (e) {
      debugPrint('Error loading reminder settings: $e');
    }

    // Re-register WorkManager periodic task if reminders were enabled
    if (_isEnabled) {
      try {
        await WorkmanagerService.registerScheduledCheck();
      } catch (_) {
        // WorkManager registration is best-effort
      }
    }

    notifyListeners();
  }

  /// Save enabled state to SharedPreferences.
  Future<void> _saveEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, _isEnabled);
    } catch (e) {
      debugPrint('Error saving reminder settings: $e');
    }
  }

  /// Save weekly summary enabled state.
  Future<void> _saveWeeklyEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWeeklyEnabled, _weeklyEnabled);
    } catch (e) {
      debugPrint('Error saving weekly summary settings: $e');
    }
  }

  /// Enable or disable the random daily notifications.
  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    notifyListeners();
    await _saveEnabled();
    await RandomNotificationService.setEnabled(value);
    if (_isEnabled) {
      await WorkmanagerService.registerScheduledCheck();
    } else {
      await WorkmanagerService.cancelScheduledCheck();
    }
  }

  /// Enable or disable the weekly summary notification independently.
  Future<void> setWeeklyEnabled(bool value) async {
    _weeklyEnabled = value;
    notifyListeners();
    await _saveWeeklyEnabled();
    await RandomNotificationService.setWeeklyEnabled(value);
  }

  /// Toggle the reminder on/off.
  Future<void> toggle() async {
    await setEnabled(!_isEnabled);
  }

  /// Calculate weekly summary stats: how many of the past 7 days had all habits completed.
  Future<({int daysAllDone, int totalDays})> calculateWeeklyStats() async {
    final now = DateTime.now();
    final db = DatabaseService.instance;
    List<Habit> habits;
    try {
      habits = await db.getHabits();
    } catch (_) {
      habits = [];
    }
    if (habits.isEmpty) return (daysAllDone: 0, totalDays: 7);

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    int daysAllDone = 0;
    for (int i = 1; i <= 7; i++) {
      final day = now.subtract(Duration(days: i));
      final dateStr = formatDate(day);
      try {
        final completions = await db.getCompletionsForDate(dateStr);
        final completedIds = completions.map((c) => c.habitId).toSet();
        if (habits.every((h) => h.id != null && completedIds.contains(h.id))) {
          daysAllDone++;
        }
      } catch (_) {
        // Skip this day on error
      }
    }
    return (daysAllDone: daysAllDone, totalDays: 7);
  }

  /// Show the weekly summary notification now.
  Future<void> showWeeklySummary() async {
    if (!_weeklyEnabled) return;
    final stats = await calculateWeeklyStats();
    await NotificationService.instance.showWeeklySummaryNotification(
      daysAllDone: stats.daysAllDone,
      totalDays: stats.totalDays,
    );
  }

  /// Check if today is Sunday and show the weekly summary.
  Future<void> checkAndShowWeeklySummary() async {
    if (!_weeklyEnabled) return;
    if (DateTime.now().weekday != DateTime.sunday) return;

    // Check if already shown this Sunday
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString('weekly_summary_last_shown') ?? '';
      final today = DateTime.now();
      final todayStr =
          '${today.year}-W${_isoWeekNumber(today)}';
      if (lastShown == todayStr) return;

      final stats = await calculateWeeklyStats();
      await NotificationService.instance.showWeeklySummaryNotification(
        daysAllDone: stats.daysAllDone,
        totalDays: stats.totalDays,
      );
      await prefs.setString('weekly_summary_last_shown', todayStr);
    } catch (_) {}
  }

  /// Calculate ISO week number for deduplication.
  int _isoWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(startOfYear).inDays;
    return ((days + startOfYear.weekday - 1) / 7).ceil();
  }
}
