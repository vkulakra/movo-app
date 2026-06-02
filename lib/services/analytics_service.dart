import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized analytics service for Firebase Analytics.
///
/// Provides helper methods for tracking screen views and key user actions
/// throughout the app. Falls back silently if Firebase is unavailable.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// A [NavigatorObserver] that automatically logs screen transitions.
  /// Attach this to your [MaterialApp.navigatorObservers].
  final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: FirebaseAnalytics.instance,
  );

  // ── Screen tracking ──────────────────────────────────────────

  /// Log a screen view. Call this in `initState()` of each screen.
  Future<void> logScreen(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
    } catch (_) {
      // Firebase Analytics unavailable — silently ignore.
    }
  }

  // ── User actions ─────────────────────────────────────────────

  /// Fired when a user completes a habit (marks it done for the day).
  Future<void> logHabitCompleted(String habitName) async {
    try {
      await _analytics.logEvent(
        name: 'habit_completed',
        parameters: {'habit_name': habitName},
      );
    } catch (_) {}
  }

  /// Fired when a user logs a new mood entry.
  Future<void> logMoodLogged(int score, String label) async {
    try {
      await _analytics.logEvent(
        name: 'mood_logged',
        parameters: {'score': score, 'label': label},
      );
    } catch (_) {}
  }

  /// Fired when a user creates a new habit.
  Future<void> logHabitCreated(String habitName) async {
    try {
      await _analytics.logEvent(
        name: 'habit_created',
        parameters: {'habit_name': habitName},
      );
    } catch (_) {}
  }

  /// Fired when a user deletes a habit.
  Future<void> logHabitDeleted() async {
    try {
      await _analytics.logEvent(name: 'habit_deleted');
    } catch (_) {}
  }

  /// Fired when a user opens the app (first time in a session).
  Future<void> logAppOpened() async {
    try {
      await _analytics.logEvent(name: 'app_opened');
    } catch (_) {}
  }

  /// Fired when a user enables/disables ad removal via IAP.
  Future<void> logAdsRemovedToggled(bool removed) async {
    try {
      await _analytics.logEvent(
        name: 'ads_removed_toggled',
        parameters: {'removed': removed ? 'yes' : 'no'},
      );
    } catch (_) {}
  }

  /// Fired when an ad is shown (banner, interstitial, or native).
  Future<void> logAdShown(String adType) async {
    try {
      await _analytics.logEvent(
        name: 'ad_shown',
        parameters: {'type': adType},
      );
    } catch (_) {}
  }
}
