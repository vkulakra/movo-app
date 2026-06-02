import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages interstitial ads with preloading and a configurable minimum interval
/// between shows to avoid overwhelming the user.
///
/// Usage:
/// ```dart
/// final manager = InterstitialAdManager(
///   isAdsRemoved: () => adProvider.adsRemoved,
/// );
/// await manager.preload();
/// manager.showIfReady();
/// ```
class InterstitialAdManager {
  InterstitialAd? _interstitialAd;
  DateTime? _lastShown;
  bool _isLoading = false;

  /// Minimum time between interstitial shows (default: 60 seconds).
  final Duration minInterval;

  /// Optional callback to check if ads have been removed (e.g., via IAP).
  final bool Function()? isAdsRemoved;

  InterstitialAdManager({
    this.minInterval = const Duration(seconds: 60),
    this.isAdsRemoved,
  });

  /// Whether an ad is loaded and ready to show.
  bool get isReady => _interstitialAd != null && !_isLoading;

  /// Whether enough time has passed since the last show.
  bool get _canShowByInterval {
    if (_lastShown == null) return true;
    return DateTime.now().difference(_lastShown!) >= minInterval;
  }

  /// The interstitial ad unit ID for each platform.
  static String? _adUnitId() {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7378651540822428/6925687375'; // Real interstitial ad unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial ID
    }
    return null;
  }

  /// Preload an interstitial ad. Call this early (e.g., in initState) so the
  /// ad is ready when the user reaches a natural breakpoint.
  Future<void> preload() async {
    // Don't preload if ads are removed
    if (isAdsRemoved != null && isAdsRemoved!()) return;

    final adUnitId = _adUnitId();
    if (adUnitId == null) return;

    // Avoid stacking multiple preloads
    if (_isLoading || _interstitialAd != null) return;

    _isLoading = true;

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(
        nonPersonalizedAds: true,
      ),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;

          // Log which mediation adapter loaded this ad (useful for debugging)
          final adapter = ad.responseInfo?.mediationAdapterClassName;
          debugPrint('InterstitialAd loaded via: $adapter');

          // Auto-dispose old ad when a new one replaces it
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              // Preload the next ad immediately after dismissal
              _isLoading = false;
              preload();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('InterstitialAd failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              _isLoading = false;
              preload();
            },
            onAdShowedFullScreenContent: (ad) {
              _lastShown = DateTime.now();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Show the interstitial ad if one is loaded, enough time has passed since
  /// the last show, and ads have not been removed. Returns true if the ad was
  /// shown, false otherwise.
  bool showIfReady() {
    // Don't show if ads are removed
    if (isAdsRemoved != null && isAdsRemoved!()) return false;

    if (!isReady || !_canShowByInterval) return false;

    _interstitialAd!.show();
    return true;
  }

  /// Dispose the current interstitial ad. Call in your widget's dispose().
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
  }
}
