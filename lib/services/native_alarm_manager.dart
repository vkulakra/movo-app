import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter-side interface to the native Android [AlarmManager.setAlarmClock] API.
///
/// This is the **most reliable** scheduling mechanism on Android because
/// `setAlarmClock` is exempt from ALL battery optimizations (Doze mode, OEM
/// power management, etc.). It uses the same API as actual alarm clock apps.
///
/// On iOS/macOS/web, this class is a no-op (it returns false from all methods).
class NativeAlarmManager {
  static const _channel = MethodChannel('com.habitmood.habit_mood_journal/alarm');

  /// Whether the native alarm manager is available (Android only).
  static bool get isAvailable {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Callback invoked when the native alarm fires and the user interacts.
  ///
  /// [action] is one of `'task_done'`, `'not_done'`, or `'alarm_fired'` (body
  /// tapped without an action button).
  static void Function(String action)? onAlarmAction;

  /// Initialize the MethodChannel handler for receiving alarm actions from
  /// native code. Must be called from the main isolate.
  static Future<void> initialize() async {
    if (!isAvailable) return;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlarmAction':
        final action = call.arguments as String?;
        if (action != null && onAlarmAction != null) {
          onAlarmAction!(action);
        }
        return true;
      default:
        throw MissingPluginException();
    }
  }

  /// Schedule a daily alarm using [AlarmManager.setAlarmClock].
  ///
  /// The alarm will fire at [hour]:[minute] each day. When it fires, the native
  /// broadcast receiver shows a notification with "Task Done" / "Not Done"
  /// action buttons.
  static Future<bool> scheduleAlarm({
    required int hour,
    required int minute,
  }) async {
    if (!isAvailable) return false;
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'hour': hour,
        'minute': minute,
      });
      return true;
    } catch (e) {
      debugPrint('scheduleAlarm error: $e');
      return false;
    }
  }

  /// Cancel the previously scheduled alarm.
  static Future<bool> cancelAlarm() async {
    if (!isAvailable) return false;
    try {
      await _channel.invokeMethod('cancelAlarm');
      return true;
    } catch (e) {
      debugPrint('cancelAlarm error: $e');
      return false;
    }
  }

  /// Check whether the native alarm has already shown today's notification.
  ///
  /// This reads from a native-only SharedPreferences file, separate from
  /// Flutter's shared_preferences plugin. It's used to prevent duplicate
  /// notifications when the app resumes.
  static Future<bool> isAlarmShownToday() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod('isAlarmShownToday') as bool;
    } catch (e) {
      debugPrint('isAlarmShownToday error: $e');
      return false;
    }
  }

  /// Mark the native alarm as having shown today's notification.
  ///
  /// Called from Flutter when handling a notification action or missed check
  /// to keep the native-side flag in sync.
  static Future<void> markAlarmShownToday() async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('markAlarmShownToday');
    } catch (e) {
      debugPrint('markAlarmShownToday error: $e');
    }
  }

  /// Get any pending alarm action that arrived before the Flutter handler was set up.
  ///
  /// Called immediately after [initialize] to handle cold-start actions.
  /// Returns the action string (e.g. `'task_done'`, `'not_done'`, `'alarm_fired'`)
  /// or `null` if there's no pending action.
  static Future<String?> getPendingAlarmAction() async {
    if (!isAvailable) return null;
    try {
      return await _channel.invokeMethod('getPendingAlarmAction') as String?;
    } catch (e) {
      debugPrint('getPendingAlarmAction error: $e');
      return null;
    }
  }

  /// Get the currently scheduled alarm hour from native storage.
  static Future<int> getScheduledHour() async {
    if (!isAvailable) return 19;
    try {
      return await _channel.invokeMethod('getScheduledHour') as int;
    } catch (e) {
      debugPrint('getScheduledHour error: $e');
      return 19;
    }
  }

  /// Get the currently scheduled alarm minute from native storage.
  static Future<int> getScheduledMinute() async {
    if (!isAvailable) return 0;
    try {
      return await _channel.invokeMethod('getScheduledMinute') as int;
    } catch (e) {
      debugPrint('getScheduledMinute error: $e');
      return 0;
    }
  }
}
