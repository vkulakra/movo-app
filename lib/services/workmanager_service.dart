import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Unique name for the periodic reminder check task.
const String _periodicTaskName = 'com.habitmood.reminder_check';
const String _periodicTaskTag = 'reminderCheck';

/// SharedPreferences keys — must match those in [ReminderProvider].
const String _keyEnabled = 'reminder_enabled';
const String _keyHour = 'reminder_hour';
const String _keyMinute = 'reminder_minute';
const String _keyLastShownDate = 'reminder_last_shown_date';

/// Callback dispatcher for WorkManager background tasks.
///
/// This runs in a **background isolate**, so it cannot access any app state,
/// providers, or global instances from the main isolate. It reads reminder
/// settings directly from SharedPreferences and shows a notification via a
/// fresh [FlutterLocalNotificationsPlugin] instance.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // --- Read reminder settings from SharedPreferences ---
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_keyEnabled) ?? false;

    // Short-circuit if reminders are disabled
    if (!isEnabled) return Future.value(true);

    final hour = prefs.getInt(_keyHour) ?? 19;
    final minute = prefs.getInt(_keyMinute) ?? 0;

    // --- Check if scheduled time has passed today ---
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    // Don't show if the reminder time hasn't come yet
    if (now.isBefore(scheduled)) return Future.value(true);

    // --- Check if already shown today ---
    final lastShown = prefs.getString(_keyLastShownDate) ?? '';
    final todayDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (lastShown == todayDateStr) return Future.value(true);

    // --- Mark as shown to avoid duplicates ---
    await prefs.setString(_keyLastShownDate, todayDateStr);

    // --- Show the reminder notification ---
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await flutterLocalNotificationsPlugin.initialize(settings);

      const androidDetails = AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily reminders to complete your habits',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            'task_done',
            'Task Done',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'not_done',
            'Not Done',
            cancelNotification: true,
          ),
        ],
      );
      const details = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        1, // Use the same daily-reminder ID as NotificationService
        'Movo Reminder',
        'Time to check in with your habits!',
        details,
      );
    } catch (e) {
      // Log is not available in background isolate — silently fail
    }

    return Future.value(true);
  });
}

/// Manages a periodic WorkManager task that checks if a reminder is due.
class WorkmanagerService {
  static bool _initialized = false;

  /// Initialize WorkManager with the [callbackDispatcher].
  ///
  /// Must be called from the main isolate before [runApp].
  static Future<void> initialize() async {
    if (_initialized) return;
    await Workmanager().initialize(callbackDispatcher);
    _initialized = true;
  }

  /// Register the periodic reminder check (every 15 minutes, minimum interval).
  ///
  /// Call this when reminders are enabled. The task shows a notification
  /// if the scheduled reminder time has passed and hasn't been shown yet.
  static Future<void> registerScheduledCheck() async {
    await Workmanager().registerPeriodicTask(
      _periodicTaskName,
      _periodicTaskTag,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 10),
    );
  }

  /// Cancel the periodic reminder check.
  ///
  /// Call this when reminders are disabled.
  static Future<void> cancelScheduledCheck() async {
    await Workmanager().cancelByUniqueName(_periodicTaskName);
  }
}
