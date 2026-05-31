import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Unique name for the periodic reminder check task.
const String _periodicTaskName = 'com.habitmood.reminder_check';
const String _periodicTaskTag = 'reminderCheck';

/// Callback dispatcher for WorkManager background tasks.
///
/// This runs in a **background isolate**, so it cannot access any app state,
/// providers, or global instances from the main isolate. It reads notification
/// settings directly from SharedPreferences and shows notifications via a
/// fresh [FlutterLocalNotificationsPlugin] instance.
///
/// Rather than firing at a specific time, it checks 4 random time windows
/// (morning, afternoon, evening, night) and fires at most one notification
/// per window per day — no alarm permissions required.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final prefs = await SharedPreferences.getInstance();

    // ── Helper: show a notification using a local plugin instance ──
    Future<void> showNotif(String title, String body) async {
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
        title,
        body,
        details,
      );
    }

    // ── Check each time window and fire if due ──
    final enabled = prefs.getBool('random_notif_enabled') ?? false;
    if (!enabled) return Future.value(true);

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Define the 4 time windows inline (avoids importing the service)
    const windows = <(String, int, int, int, int)>[
      ('morning', 6, 0, 10, 59),
      ('afternoon', 11, 0, 14, 59),
      ('evening', 15, 0, 18, 59),
      ('night', 19, 0, 21, 59),
    ];

    final currentMinutes = now.hour * 60 + now.minute;

    for (final (name, startH, startM, endH, endM) in windows) {
      final startMinutes = startH * 60 + startM;
      final endMinutes = endH * 60 + endM;

      // Not in this window yet
      if (currentMinutes < startMinutes || currentMinutes > endMinutes) {
        continue;
      }

      // Already fired today
      final key = 'random_notif_${name}_last_fired';
      if (prefs.getString(key) == todayStr) continue;

      // Pick a random message
      String title;
      String body;

      switch (name) {
        case 'morning':
          title = '☀️ Good Morning!';
          body = _pick([
            'Good morning! ☀️ Ready to check in with your habits today?',
            'Rise and shine! 🌅 Time to make today count.',
            'Morning check-in! 🏃 What habits are on your list today?',
            'New day, new wins! 🎯 Start strong with your habits.',
            'Good morning, you got this! 💪 Quick habit check?',
            'Today is full of possibilities! 🌟 Log your habits now.',
            'Wake up and grind! 🔥 Your habits are waiting.',
            'Morning vibes only! ✨ How are we doing today?',
          ]);
        case 'afternoon':
          title = '☀️ Afternoon Check-In';
          body = _pick([
            'Afternoon check-in! ☀️ How are your habits going so far?',
            'Halfway through the day! 📊 Don\'t forget your habits.',
            'How\'s your day shaping up? 🤔 Quick habit reminder!',
            'Lunchtime reminder! 🍱 Have you checked your habits?',
            'Midday motivation! 🚀 You\'re doing great — keep it up!',
            'Checking in! 📝 How are those habits looking today?',
            'Afternoon vibes! 🌻 Time for a habit status update.',
            'Don\'t let the afternoon slump get you! ⚡ Power through!',
          ]);
        case 'evening':
          title = '🌆 Evening Check-In';
          body = _pick([
            'Evening check-in! 🌆 How did your habits go today?',
            'Sun is setting! 🌅 Time to reflect on today\'s habits.',
            'Evening reminder! 🌙 Have you completed your habits?',
            'Almost done for the day! 🏁 Finish those habits strong.',
            'How was your day? 📓 Quick habit log before you forget!',
            'Evening wind-down! 🧘 Log your habits and relax.',
            'Day\'s almost over! ⏰ Last chance for today\'s habits.',
            'Great job today! 🌟 Let\'s check those habits off.',
          ]);
        case 'night':
          title = '🌙 Night Check-In';
          body = _pick([
            'Night check-in! 🌙 Time to wrap up today\'s habits.',
            'Before you sleep! 🌠 Quick habit review for today.',
            'Daily recap time! 📋 How did your habits go?',
            'One last check! ✨ All habits done for the day?',
            'Nighttime reflection! 🧠 Think about today\'s wins.',
            'Rest time soon! 🛌 But first — how were your habits?',
            'End of day check! ✅ Tally up today\'s habit progress.',
            'Tomorrow starts now! 📅 Set yourself up for success.',
          ]);
        default:
          title = 'Movo Reminder';
          body = 'Time to check in with your habits!';
      }

      try {
        await showNotif(title, body);
      } catch (_) {
        return Future.value(true);
      }

      // Mark as fired
      await prefs.setString(key, todayStr);
      break; // Only one notification per check cycle
    }

    return Future.value(true);
  });
}

/// Pick a random element from a list using a deterministic seed based on time.
String _pick(List<String> items) {
  return items[DateTime.now().millisecondsSinceEpoch % items.length];
}

/// Manages a periodic WorkManager task that checks random notification windows.
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
  /// The task checks the 4 daily time windows (morning, afternoon, evening,
  /// night) and fires a random notification if the current time falls within
  /// an unfired window. No alarm permissions required.
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
  static Future<void> cancelScheduledCheck() async {
    await Workmanager().cancelByUniqueName(_periodicTaskName);
  }
}
