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
  AdSize? _adaptiveSize;

  /// Google-provided test ad unit IDs.
  /// Replace with your real AdMob ad unit IDs before production release.
  static String? _adUnitId() {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7378651540822428/8782224751'; // Real AdMob banner ID
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
      // Wait for first frame so MediaQuery is available for adaptive sizing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _getAdaptiveSizeAndLoad(adUnitId);
      });
    } else {
      _hasFailed = true;
    }
  }

  Future<void> _getAdaptiveSizeAndLoad(String adUnitId) async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );
    if (!mounted) return;

    // Adaptive size is null on some platforms — fall back to standard banner
    final bannerSize = size ?? AdSize.banner;
    _adaptiveSize = bannerSize;
    _loadAd(adUnitId, bannerSize);
  }

  void _loadAd(String adUnitId, AdSize size) {
    BannerAd(
      adUnitId: adUnitId,
      size: size,
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
          // Log which mediation adapter served this ad (useful for debugging)
          final adapter = ad.responseInfo?.mediationAdapterClassName;
          debugPrint('BannerAd loaded via: $adapter');
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

    if (!_isLoaded || _bannerAd == null || _adaptiveSize == null) {
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

    // Use the adaptive banner height for a polished layout
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      height: _adaptiveSize!.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
