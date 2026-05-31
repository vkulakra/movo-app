package com.habitmood.habit_mood_journal

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Receives the [AlarmManager.setAlarmClock] broadcast and shows a native notification.
 *
 * Because `setAlarmClock` is exempt from all battery optimizations (Doze, OEM hacks),
 * this is the most reliable scheduling mechanism on devices like Realme/ColorOS.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmReceiver"
        private const val PREFS_FILE = "habit_mood_alarm_prefs"
        private const val KEY_SHOWN_DATE = "native_alarm_shown_date"
        private const val KEY_HOUR = "native_alarm_hour"
        private const val KEY_MINUTE = "native_alarm_minute"

        private const val NOTIFICATION_ID = 100
        private const val ALARM_REQUEST_CODE = 200

        // Intent extra keys
        const val EXTRA_ACTION = "native_alarm_action"
        const val EXTRA_HOUR = "native_alarm_hour"
        const val EXTRA_MINUTE = "native_alarm_minute"

        // Action values
        const val ACTION_TASK_DONE = "task_done"
        const val ACTION_NOT_DONE = "not_done"
        const val ACTION_ALARM_FIRED = "alarm_fired"

        // Request codes for PendingIntents
        private const val RC_CONTENT = 0
        private const val RC_DONE = 1
        private const val RC_NOT_DONE = 2
        private const val RC_SHOW = 10
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra(EXTRA_ACTION)
        Log.d(TAG, "onReceive action=$action")

        when (action) {
            ACTION_TASK_DONE -> openAppWithAction(context, ACTION_TASK_DONE)
            ACTION_NOT_DONE -> openAppWithAction(context, ACTION_NOT_DONE)
            else -> handleAlarmFired(context, intent)
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Alarm-fired: show notification, mark shown, reschedule
    // ──────────────────────────────────────────────────────────────

    private fun handleAlarmFired(context: Context, intent: Intent) {
        val hour = intent.getIntExtra(EXTRA_HOUR, 19)
        val minute = intent.getIntExtra(EXTRA_MINUTE, 0)

        // Persist the scheduled time so reschedule can use it
        persistScheduledTime(context, hour, minute)

        // Show native notification with action buttons
        showNotification(context)

        // Mark as shown today in native prefs so Flutter can check it
        markAlarmShownToday(context)

        // Reschedule for the next day at the same time
        reschedule(context, hour, minute)
    }

    // ──────────────────────────────────────────────────────────────
    // Notification display
    // ──────────────────────────────────────────────────────────────

    private fun showNotification(context: Context) {
        val channelId = "habit_reminders"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel (may already exist — idempotent)
        val channel = NotificationChannel(
            channelId,
            "Habit Reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Daily reminders to complete your habits"
        }
        nm.createNotificationChannel(channel)

        // Content PendingIntent — opens the app
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_ACTION, ACTION_ALARM_FIRED)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context, RC_CONTENT, contentIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // "Task Done" action PendingIntent
        val doneIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(EXTRA_ACTION, ACTION_TASK_DONE)
        }
        val donePendingIntent = PendingIntent.getBroadcast(
            context, RC_DONE, doneIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // "Not Done" action PendingIntent
        val notDoneIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(EXTRA_ACTION, ACTION_NOT_DONE)
        }
        val notDonePendingIntent = PendingIntent.getBroadcast(
            context, RC_NOT_DONE, notDoneIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Movo Reminder")
            .setContentText("Time to check in with your habits!")
            .setContentIntent(contentPendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_edit, "Task Done", donePendingIntent
                ).build()
            )
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_delete, "Not Done", notDonePendingIntent
                ).build()
            )
            .build()

        try {
            nm.notify(NOTIFICATION_ID, notification)
            Log.d(TAG, "Notification shown (id=$NOTIFICATION_ID)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show notification", e)
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Action handling — opens MainActivity with action extra
    // ──────────────────────────────────────────────────────────────

    private fun openAppWithAction(context: Context, action: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_ACTION, action)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app for action=$action", e)
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Scheduling with setAlarmClock
    // ──────────────────────────────────────────────────────────────

    /** Schedule a repeating daily alarm using [AlarmManager.setAlarmClock]. */
    private fun reschedule(context: Context, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Calculate next occurrence: tomorrow at hour:minute
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            // If today's time hasn't passed yet, use today; otherwise tomorrow
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }

        // Show PendingIntent — displayed on the lock screen as "alarm clock" indicator
        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context, RC_SHOW, showIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        try {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(calendar.timeInMillis, showPendingIntent),
                pendingIntent
            )
            Log.d(TAG, "Alarm scheduled at ${calendar.time}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm", e)
        }
    }

    /** Cancel the pending alarm. */
    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
        )
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
            Log.d(TAG, "Alarm cancelled")
        }
    }

    // ──────────────────────────────────────────────────────────────
    // SharedPreferences helpers (native-only file)
    // ──────────────────────────────────────────────────────────────

    private fun persistScheduledTime(context: Context, hour: Int, minute: Int) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(KEY_HOUR, hour)
            .putInt(KEY_MINUTE, minute)
            .apply()
    }

    private fun markAlarmShownToday(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        prefs.edit().putString(KEY_SHOWN_DATE, today).apply()
        Log.d(TAG, "Marked alarm shown for date: $today")
    }

    /** Static helpers — called from the MethodChannel in MainActivity.kt */

    fun isAlarmShownToday(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val stored = prefs.getString(KEY_SHOWN_DATE, "") ?: ""
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        return stored == today
    }

    fun markShownToday(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        prefs.edit().putString(KEY_SHOWN_DATE, today).apply()
    }

    fun getScheduledHour(context: Context): Int {
        return context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .getInt(KEY_HOUR, 19)
    }

    fun getScheduledMinute(context: Context): Int {
        return context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .getInt(KEY_MINUTE, 0)
    }

    /** Convenience: schedule given hour/minute (called from Flutter via MethodChannel). */
    fun schedule(context: Context, hour: Int, minute: Int) {
        persistScheduledTime(context, hour, minute)
        reschedule(context, hour, minute)
    }
}
