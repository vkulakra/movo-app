import 'package:shared_preferences/shared_preferences.dart';

/// Defines a daily notification time window.
class NotificationWindow {
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const NotificationWindow({
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  bool get isAllDay =>
      startHour == 0 && startMinute == 0 && endHour == 23 && endMinute == 59;
}

/// Manages random daily notifications in 4 time windows:
///   - Morning    (06:00–10:59)
///   - Afternoon  (11:00–14:59)
///   - Evening    (15:00–18:59)
///   - Night      (19:00–21:59)
///
/// Each window fires at most one notification per day. The exact firing time
/// within each window is determined by the [WorkManager] periodic check —
/// whichever 15-minute tick lands inside the window triggers the notification.
///
/// No [AlarmManager] permissions are required because scheduling is handled by
/// [WorkManager]'s built-in periodic task (minimum 15 min interval).
class RandomNotificationService {
  RandomNotificationService._();
  static final RandomNotificationService instance =
      RandomNotificationService._();

  static const String _keyPrefix = 'random_notif_';
  static const String _keyEnabled = '${_keyPrefix}enabled';
  static const String _weeklyEnabledKey = 'weekly_summary_enabled';

  /// The four daily notification windows.
  static const List<NotificationWindow> windows = [
    NotificationWindow(
      name: 'morning',
      startHour: 6,
      startMinute: 0,
      endHour: 10,
      endMinute: 59,
    ),
    NotificationWindow(
      name: 'afternoon',
      startHour: 11,
      startMinute: 0,
      endHour: 14,
      endMinute: 59,
    ),
    NotificationWindow(
      name: 'evening',
      startHour: 15,
      startMinute: 0,
      endHour: 18,
      endMinute: 59,
    ),
    NotificationWindow(
      name: 'night',
      startHour: 19,
      startMinute: 0,
      endHour: 21,
      endMinute: 59,
    ),
  ];

  // ── Motivational messages per window ──

  static const List<String> _morningMessages = [
    'Good morning! ☀️ Ready to check in with your habits today?',
    'Rise and shine! 🌅 Time to make today count.',
    'Morning check-in! 🏃 What habits are on your list today?',
    'New day, new wins! 🎯 Start strong with your habits.',
    'Good morning, you got this! 💪 Quick habit check?',
    'Today is full of possibilities! 🌟 Log your habits now.',
    'Wake up and grind! 🔥 Your habits are waiting.',
    'Morning vibes only! ✨ How are we doing today?',
  ];

  static const List<String> _afternoonMessages = [
    'Afternoon check-in! ☀️ How are your habits going so far?',
    'Halfway through the day! 📊 Don\'t forget your habits.',
    'How\'s your day shaping up? 🤔 Quick habit reminder!',
    'Lunchtime reminder! 🍱 Have you checked your habits?',
    'Midday motivation! 🚀 You\'re doing great — keep it up!',
    'Checking in! 📝 How are those habits looking today?',
    'Afternoon vibes! 🌻 Time for a habit status update.',
    'Don\'t let the afternoon slump get you! ⚡ Power through!',
  ];

  static const List<String> _eveningMessages = [
    'Evening check-in! 🌆 How did your habits go today?',
    'Sun is setting! 🌅 Time to reflect on today\'s habits.',
    'Evening reminder! 🌙 Have you completed your habits?',
    'Almost done for the day! 🏁 Finish those habits strong.',
    'How was your day? 📓 Quick habit log before you forget!',
    'Evening wind-down! 🧘 Log your habits and relax.',
    'Day\'s almost over! ⏰ Last chance for today\'s habits.',
    'Great job today! 🌟 Let\'s check those habits off.',
  ];

  static const List<String> _nightMessages = [
    'Night check-in! 🌙 Time to wrap up today\'s habits.',
    'Before you sleep! 🌠 Quick habit review for today.',
    'Daily recap time! 📋 How did your habits go?',
    'One last check! ✨ All habits done for the day?',
    'Nighttime reflection! 🧠 Think about today\'s wins.',
    'Rest time soon! 🛌 But first — how were your habits?',
    'End of day check! ✅ Tally up today\'s habit progress.',
    'Tomorrow starts now! 📅 Set yourself up for success.',
  ];

  /// Returns the appropriate message list for the current time window.
  static List<String> _messagesForWindow(NotificationWindow window) {
    switch (window.name) {
      case 'morning':
        return _morningMessages;
      case 'afternoon':
        return _afternoonMessages;
      case 'evening':
        return _eveningMessages;
      case 'night':
        return _nightMessages;
      default:
        return _afternoonMessages;
    }
  }

  /// SharedPreferences key for tracking whether a window fired today.
  static String _firedKey(String windowName) =>
      '$_keyPrefix${windowName}_last_fired';

  /// Date string format used for tracking.
  static String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if the current time falls within [window].
  static bool isInWindow(NotificationWindow window) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = window.startHour * 60 + window.startMinute;
    final endMinutes = window.endHour * 60 + window.endMinute;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  /// Find which window the current time falls in, or null if none.
  static NotificationWindow? get currentWindow {
    for (final w in windows) {
      if (isInWindow(w)) return w;
    }
    return null;
  }

  /// Pick a random message for [window].
  static String pickRandomMessage(NotificationWindow window) {
    final messages = _messagesForWindow(window);
    return messages[DateTime.now().millisecondsSinceEpoch % messages.length];
  }

  /// Check whether a notification has already been shown for [window] today.
  static Future<bool> hasWindowFiredToday(String windowName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_firedKey(windowName)) == _todayDateStr();
    } catch (_) {
      return false;
    }
  }

  /// Mark [window] as having fired today.
  static Future<void> markWindowFired(String windowName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_firedKey(windowName), _todayDateStr());
    } catch (_) {}
  }

  /// Reset all window tracking (e.g., when the date changes).
  static Future<void> resetAllWindows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final w in windows) {
        await prefs.remove(_firedKey(w.name));
      }
    } catch (_) {}
  }

  /// Load whether random notifications are enabled.
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persist the enabled state.
  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, value);
    } catch (_) {}
  }

  /// Load whether weekly summary is enabled.
  static Future<bool> isWeeklyEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_weeklyEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persist weekly summary enabled state.
  static Future<void> setWeeklyEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_weeklyEnabledKey, value);
    } catch (_) {}
  }

  // ── Background-friendly check (no Flutter dependencies) ──

  /// Background-isolate-friendly check: determines if a random notification
  /// should fire right now, and if so, shows it.
  ///
  /// Returns `true` if a notification was shown.
  ///
  /// This method is safe to call from the WorkManager background isolate.
  /// [prefs] must be an already-initialized SharedPreferences instance.
  /// [notifPlugin] is a fresh [FlutterLocalNotificationsPlugin] instance
  /// created in the background isolate.
  static Future<bool> checkAndFire({
    required SharedPreferences prefs,
    required dynamic showNotificationFn, // (String title, String body) => Future<void>
  }) async {
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    if (!enabled) return false;

    final now = DateTime.now();
    final todayStr = _todayDateStr();

    // Determine which window we're in, and whether it has already fired
    for (final window in windows) {
      // Check if current time is in this window
      final currentMinutes = now.hour * 60 + now.minute;
      final startMinutes = window.startHour * 60 + window.startMinute;
      final endMinutes = window.endHour * 60 + window.endMinute;

      if (currentMinutes < startMinutes || currentMinutes > endMinutes) {
        continue; // Not in this window
      }

      // Check if already fired today
      final lastFired = prefs.getString(_firedKey(window.name)) ?? '';
      if (lastFired == todayStr) continue; // Already fired

      // Fire the notification!
      final title = _titleForWindow(window.name);
      final body = pickRandomMessage(window);

      try {
        await showNotificationFn(title, body);
      } catch (_) {
        return false;
      }

      // Mark as fired
      await prefs.setString(_firedKey(window.name), todayStr);
      return true;
    }

    return false;
  }

  /// Build an appropriate notification title for each window.
  static String _titleForWindow(String windowName) {
    switch (windowName) {
      case 'morning':
        return '☀️ Good Morning!';
      case 'afternoon':
        return '☀️ Afternoon Check-In';
      case 'evening':
        return '🌆 Evening Check-In';
      case 'night':
        return '🌙 Night Check-In';
      default:
        return 'Movo Reminder';
    }
  }
}
