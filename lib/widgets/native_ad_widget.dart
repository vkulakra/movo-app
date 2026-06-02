import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A native ad card that blends into the app's content feed.
///
/// Uses [NativeTemplateStyle] to match the app's card design (rounded corners,
/// consistent background colors). Place it in lists between every N items.
///
/// ## Ad unit IDs
/// - Android: `ca-app-pub-7378651540822428/5997718709`
/// - iOS: `ca-app-pub-3940256099942544/3986624511` (test — replace before iOS launch)
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with SingleTickerProviderStateMixin {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _hasFailed = false;
  late final AnimationController _shimmerController;

  static String? _adUnitId() {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7378651540822428/5997718709'; // Real Android native ad unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511'; // TODO: Replace with real iOS native ad ID before launch
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nativeAd == null && !_hasFailed) {
      _loadAd();
    }
  }

  void _loadAd() {
    final adUnitId = _adUnitId();
    if (adUnitId == null) {
      setState(() => _hasFailed = true);
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(
        nonPersonalizedAds: true,
      ),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('NativeAd loaded.');
          if (!mounted) {
            ad.dispose();
            return;
          }
          // Defer setState to prevent re-entrant layout if the ad loads
          // synchronously during the current frame's layout phase.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isLoaded = true);
            }
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('NativeAd failed to load: $error');
          ad.dispose();
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _nativeAd = null;
                _hasFailed = true;
              });
            }
          });
        },
        onAdOpened: (Ad ad) => debugPrint('NativeAd opened.'),
        onAdClosed: (Ad ad) => debugPrint('NativeAd closed.'),
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF6C63FF),
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1D1D1F),
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF8E8E93),
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF8E8E93),
          size: 11.0,
        ),
      ),
    )..load();
  }

  /// A shimmer skeleton placeholder that reserves the ad slot while loading.
  /// Prevents layout shifts when the native ad arrives.
  Widget _buildShimmerPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double adHeight = 300;

    final skeletonBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final skeletonColor =
        isDark ? const Color(0xFF2C2C36) : const Color(0xFFE8E8F0);
    final skeletonBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF6C63FF).withValues(alpha: 0.15);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: adHeight,
          decoration: BoxDecoration(
            color: skeletonBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: skeletonBorder),
          ),
          child: Stack(
            children: [
              // Static skeleton shapes
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBar(width: 180, height: 14, color: skeletonColor),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBar(
                          width: 48,
                          height: 48,
                          radius: 12,
                          color: skeletonColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _skeletonBar(
                                width: double.infinity,
                                height: 12,
                                color: skeletonColor,
                              ),
                              const SizedBox(height: 8),
                              _skeletonBar(
                                width: 200,
                                height: 12,
                                color: skeletonColor,
                              ),
                              const SizedBox(height: 8),
                              _skeletonBar(
                                width: 140,
                                height: 12,
                                color: skeletonColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _skeletonBar(
                      width: 120,
                      height: 36,
                      radius: 12,
                      color: skeletonColor,
                    ),
                  ],
                ),
              ),
              // Animated shimmer highlight that sweeps across the skeleton
              Positioned.fill(
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _shimmerController,
                    builder: (context, _) {
                      final pos = _shimmerController.value;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1 + pos * 2, 0),
                            end: Alignment(1 + pos * 2, 0),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(
                                alpha: isDark ? 0.08 : 0.25,
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBar({
    required double width,
    required double height,
    required Color color,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasFailed) return const SizedBox.shrink();
    if (!_isLoaded || _nativeAd == null) return _buildShimmerPlaceholder();

    // Constrain height to prevent infinite layout in sliver lists.
    // Medium native templates typically render between 275–350 dp tall.
    const double adHeight = 300;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: adHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1C1C1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.15),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AdWidget(ad: _nativeAd!),
          ),
        ),
      ),
    );
  }
}
