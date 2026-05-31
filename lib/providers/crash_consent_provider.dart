import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Manages the user's consent for Firebase Crashlytics crash reporting.
///
/// Stores consent locally via SharedPreferences — no account or backend needed.
/// When consent is granted, Crashlytics is enabled and a global Flutter error
/// handler is installed. When denied, Crashlytics is disabled.
class CrashConsentProvider extends ChangeNotifier {
  static const String _consentKey = 'crash_consent_given';
  static const String _promptedKey = 'crash_consent_prompted';

  bool _consentGiven;
  bool _hasPrompted;
  final bool _firebaseAvailable;

  CrashConsentProvider({
    required bool initialConsent,
    required bool initialPrompted,
    required bool firebaseAvailable,
  })  : _consentGiven = initialConsent,
        _hasPrompted = initialPrompted,
        _firebaseAvailable = firebaseAvailable;

  /// Whether the user has consented to crash reporting.
  bool get consentGiven => _consentGiven;

  /// Whether we've ever shown the consent prompt to the user.
  bool get hasPrompted => _hasPrompted;

  /// Whether Firebase Crashlytics is available on this device/build.
  bool get firebaseAvailable => _firebaseAvailable;

  /// Whether the user can change their consent (Firebase available & prompted).
  bool get canToggle => _firebaseAvailable && _hasPrompted;

  /// Grant consent — enables Crashlytics & installs global error handler.
  Future<void> grantConsent() async {
    _consentGiven = true;
    _hasPrompted = true;

    try {
      if (_firebaseAvailable) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = (errorDetails) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        };
      }
      await _persist();
    } catch (e) {
      debugPrint('Failed to enable crash reporting: $e');
    }

    notifyListeners();
  }

  /// Deny/revoke consent — disables Crashlytics & removes global handler.
  Future<void> denyConsent() async {
    _consentGiven = false;
    _hasPrompted = true;

    try {
      if (_firebaseAvailable) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
        FlutterError.onError = (errorDetails) {
          FlutterError.dumpErrorToConsole(errorDetails);
        };
      }
      await _persist();
    } catch (e) {
      debugPrint('Failed to disable crash reporting: $e');
    }

    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, _consentGiven);
    await prefs.setBool(_promptedKey, _hasPrompted);
  }
}
