import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/workmanager_service.dart';
import '../services/native_alarm_manager.dart';
import '../services/database_service.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

class ReminderProvider extends ChangeNotifier {
  static const String _keyEnabled = 'reminder_enabled';
  static const String _keyHour = 'reminder_hour';
  static const String _keyMinute = 'reminder_minute';
  static const String _keyWeeklyEnabled = 'weekly_summary_enabled';
  static const String _keyLastShownDate = 'reminder_last_shown_date';

  bool _isEnabled = false;
  bool _weeklyEnabled = true;
  int _hour = 19; // default 7:00 PM
  int _minute = 0;

  final Completer<void> _settingsLoaded = Completer<void>();

  /// A Future that completes when settings have been loaded from storage.
  Future<void> get settingsLoaded => _settingsLoaded.future;

  bool get isEnabled => _isEnabled;
  bool get weeklyEnabled => _weeklyEnabled;
  int get hour => _hour;
  int get minute => _minute;
  String get timeDisplay =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

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
      _hour = prefs.getInt(_keyHour) ?? 19;
      _minute = prefs.getInt(_keyMinute) ?? 0;
    } catch (e) {
      debugPrint('Error loading reminder settings: $e');
    } finally {
      _settingsLoaded.complete();
    }

    // Re-register WorkManager periodic task if reminders were enabled
    // (WorkManager tasks don't survive app uninstall/reinstall)
    if (_isEnabled) {
      try {
        await WorkmanagerService.registerScheduledCheck();
      } catch (_) {
        // WorkManager registration is best-effort
      }
    }

    notifyListeners();
  }

  /// Save settings to SharedPreferences and apply them.
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, _isEnabled);
      await prefs.setBool(_keyWeeklyEnabled, _weeklyEnabled);
      await prefs.setInt(_keyHour, _hour);
      await prefs.setInt(_keyMinute, _minute);
    } catch (e) {
      debugPrint('Error saving reminder settings: $e');
    }
  }

  /// Enable or disable the daily reminder.
  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    notifyListeners();
    await _saveSettings();
    if (_isEnabled) {
      await _scheduleReminder();
      await WorkmanagerService.registerScheduledCheck();
    } else {
      await NativeAlarmManager.cancelAlarm();
      await NotificationService.instance.cancelScheduledReminder();
      await NotificationService.instance.cancelWeeklySummary();
      await WorkmanagerService.cancelScheduledCheck();
    }
  }

  /// Enable or disable the weekly summary notification independently.
  Future<void> setWeeklyEnabled(bool value) async {
    _weeklyEnabled = value;
    notifyListeners();
    await _saveSettings();
    if (_weeklyEnabled) {
      await _scheduleWeeklySummary();
    } else {
      await NotificationService.instance.cancelWeeklySummary();
    }
  }

  /// Toggle the reminder on/off.
  Future<void> toggle() async {
    await setEnabled(!_isEnabled);
  }

  /// Get a debug status string about scheduling capabilities.
  Future<String> schedulingStatus() async {
    return NotificationService.instance.schedulingStatus();
  }

  /// Open the app's system info page to adjust battery/alarm settings.
  Future<void> openAppSettings() async {
    await NotificationService.instance.openAppSettings();
  }

  /// Open the battery optimization settings page directly.
  Future<void> openBatterySettings() async {
    await NotificationService.instance.openBatterySettings();
  }

  /// Set the reminder time.
  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    notifyListeners();
    await _saveSettings();
    if (_isEnabled) {
      await _scheduleReminder();
    }
  }

  /// Track that today's reminder was shown (shown, not scheduled).
  Future<void> markReminderShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await prefs.setString(_keyLastShownDate, dateStr);
    } catch (_) {}
    // Also mark in native alarm prefs to keep them in sync
    await NativeAlarmManager.markAlarmShownToday();
  }

  /// Check if today's reminder was already shown.
  /// Checks both Flutter and native alarm SharedPreferences (in case the
  /// native alarm fired but the user hasn't opened the app yet).
  Future<bool> wasReminderShownToday() async {
    // Check Flutter's own SharedPreferences first
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_keyLastShownDate) ?? '';
      final today = DateTime.now();
      final expected =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      if (stored == expected) return true;
    } catch (_) {}

    // Also check the native alarm prefs (in case native alarm fired without
    // the user interacting yet)
    try {
      if (await NativeAlarmManager.isAlarmShownToday()) return true;
    } catch (_) {}

    return false;
  }

  /// Check if the scheduled reminder time has passed today.
  /// Returns true if the current time is >= the scheduled time.
  bool get hasScheduledTimePassed {
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, _hour, _minute);
    return now.isAfter(scheduled) || now.isAtSameMomentAs(scheduled);
  }

  /// Show the reminder notification now if it was scheduled for a time that
  /// has already passed today and hasn't been shown yet.
  /// Returns true if the reminder was shown.
  Future<bool> showReminderIfDue(HabitProvider habitProv) async {
    if (!_isEnabled) return false;
    if (!hasScheduledTimePassed) return false;
    if (await wasReminderShownToday()) return false;

    final uncompletedNames = habitProv.habits
        .where((h) =>
            !habitProv.todayCompletions.any((c) => c.habitId == h.id))
        .map((h) => h.name)
        .toList();

    await NotificationService.instance.showReminderNotification(
      totalHabits: habitProv.habits.length,
      completedHabits: habitProv.todayCompletions.length,
      uncompletedHabitNames: uncompletedNames,
    );

    await markReminderShown();
    return true;
  }

  /// Reload settings and reschedule — useful after permissions change.
  Future<void> reloadAndReschedule(HabitProvider habitProv) async {
    await loadSettings();
    if (_isEnabled) {
      await rescheduleFromHabitProvider(habitProv);
    }
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

  /// Schedule the weekly summary notification for the coming Sunday.
  Future<void> _scheduleWeeklySummary() async {
    final stats = await calculateWeeklyStats();
    await NotificationService.instance.scheduleWeeklySummary(
      hour: _hour,
      minute: _minute,
      daysAllDone: stats.daysAllDone,
      totalDays: stats.totalDays,
    );
  }

  /// Schedule a reminder with the current settings.
  ///
  /// On Android: uses [NativeAlarmManager.scheduleAlarm] with
  /// [AlarmManager.setAlarmClock] — the most reliable API (exempt from all
  /// battery optimizations, including Realme/ColorOS).
  ///
  /// On other platforms: falls back to [NotificationService.scheduleDailyReminder]
  /// via [flutter_local_notifications] [zonedSchedule].
  ///
  /// The WorkManager periodic task and app-resume missed-check serve as
  /// additional fallback layers.
  Future<void> _scheduleReminder({
    int totalHabits = 0,
    int completedHabits = 0,
    List<String> uncompletedHabitNames = const [],
  }) async {
    // Cancel any existing flutter_local_notifications zonedSchedule
    await NotificationService.instance.cancelScheduledReminder();

    if (NativeAlarmManager.isAvailable) {
      // Android: use setAlarmClock (reliable even on locked-down OEMs)
      await NativeAlarmManager.scheduleAlarm(hour: _hour, minute: _minute);
    } else {
      // Other platforms: use flutter_local_notifications zonedSchedule
      await NotificationService.instance.scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
        totalHabits: totalHabits,
        completedHabits: completedHabits,
        uncompletedHabitNames: uncompletedHabitNames,
      );
    }

    // Schedule weekly summary if enabled (Sunday at same time).
    // Only schedule when there are habits — avoids unnecessary DB queries.
    if (_weeklyEnabled && totalHabits > 0) {
      await _scheduleWeeklySummary();
    }
  }

  /// Reschedule the reminder with up-to-date habit stats.
  /// Call this from screens whenever habit data changes (load, add, complete, delete).
  Future<void> rescheduleWithHabitData({
    required int totalHabits,
    required int completedHabits,
    required List<String> uncompletedHabitNames,
  }) async {
    if (!_isEnabled) return;

    await _scheduleReminder(
      totalHabits: totalHabits,
      completedHabits: completedHabits,
      uncompletedHabitNames: uncompletedHabitNames,
    );
  }

  /// Convenience: extract habit data from [habitProv] and reschedule.
  Future<void> rescheduleFromHabitProvider(HabitProvider habitProv) async {
    if (!_isEnabled) return;
    final uncompletedNames = habitProv.habits
        .where((h) =>
            !habitProv.todayCompletions.any((c) => c.habitId == h.id))
        .map((h) => h.name)
        .toList();
    await rescheduleWithHabitData(
      totalHabits: habitProv.habits.length,
      completedHabits: habitProv.todayCompletions.length,
      uncompletedHabitNames: uncompletedNames,
    );
  }
}
