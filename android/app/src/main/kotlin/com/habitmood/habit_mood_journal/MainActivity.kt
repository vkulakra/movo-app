package com.habitmood.habit_mood_journal

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_SETTINGS = "com.habitmood.habit_mood_journal/settings"
        private const val CHANNEL_ALARM = "com.habitmood.habit_mood_journal/alarm"
        private const val PKG = "com.habitmood.habit_mood_journal"

        // Pending alarm action that arrived before the Flutter handler was ready.
        // Flutter reads this via getPendingAlarmAction after its handler is set up,
        // guaranteeing the action survives the cold-start bootstrap race.
        private var pendingAlarmAction: String? = null
    }

    private val alarmReceiver = AlarmReceiver()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Settings channel (battery, app info, etc.) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SETTINGS).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$PKG")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open app settings", null)
                    }
                }
                "openBatterySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$PKG")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                        } else {
                            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$PKG")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open battery settings", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Alarm channel (AlarmManager.setAlarmClock) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ALARM).setMethodCallHandler {
            call, result ->
            try {
                when (call.method) {
                    "scheduleAlarm" -> {
                        val hour = (call.argument<Int>("hour") ?: 19).toInt()
                        val minute = (call.argument<Int>("minute") ?: 0).toInt()
                        alarmReceiver.schedule(this, hour, minute)
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        alarmReceiver.cancel(this)
                        result.success(true)
                    }
                    "isAlarmShownToday" -> {
                        result.success(alarmReceiver.isAlarmShownToday(this))
                    }
                    "markAlarmShownToday" -> {
                        alarmReceiver.markShownToday(this)
                        result.success(true)
                    }
                    "getScheduledHour" -> {
                        result.success(alarmReceiver.getScheduledHour(this))
                    }
                    "getScheduledMinute" -> {
                        result.success(alarmReceiver.getScheduledMinute(this))
                    }
                    "getPendingAlarmAction" -> {
                        val action = pendingAlarmAction
                        pendingAlarmAction = null
                        result.success(action)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERROR", e.message ?: "Unknown error", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Handle intent from AlarmReceiver (notification action tapped)
    // ──────────────────────────────────────────────────────────────

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra(AlarmReceiver.EXTRA_ACTION) ?: return

        // On a warm start the Flutter engine should be ready, so forward the
        // action immediately. On a cold start the engine isn't ready yet, so
        // queue it for later retrieval via getPendingAlarmAction.
        val engine = flutterEngine
        if (engine != null) {
            try {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_ALARM)
                    .invokeMethod("onAlarmAction", action)
                return
            } catch (_: Exception) {
                // Engine not ready yet — fall through to queue
            }
        }
        pendingAlarmAction = action
    }
}
