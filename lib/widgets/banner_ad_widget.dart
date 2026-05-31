import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A reusable banner ad widget that loads and displays a Google AdMob banner.
///
/// Uses test ad unit IDs during development. Replace with real IDs
/// before publishing to the Play Store.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;

  /// Google-provided test ad unit IDs.
  /// Replace with your real AdMob ad unit IDs before production release.
  static String? _adUnitId() {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test ID
    }
    return null; // Ads not supported on this platform
  }

  @override
  void initState() {
    super.initState();
    final adUnitId = _adUnitId();
    if (adUnitId != null) {
      _loadAd(adUnitId);
    } else {
      // No banner ads on non-Android/iOS platforms — hide immediately
      _hasFailed = true;
    }
  }

  void _loadAd(String adUnitId) {
    BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(
        // No personalisation — privacy-friendly
        keywords: [],
        nonPersonalizedAds: true,
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
          setState(() => _hasFailed = true);
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
      ),
    ).load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasFailed) {
      // Failed to load — don't reserve any space
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      // Loading placeholder — reserve space to prevent layout shift
      return const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Constrain the AdWidget height to prevent infinite-size layout errors.
    // Banner ads are 50dp tall; AdSize.banner gives the platform's banner height.
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      height: AdSize.banner.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
