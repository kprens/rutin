/// AdMob reklamları — Pro kullanıcılarda gösterilmez.
///
/// ŞU AN TEST KİMLİKLERİ KULLANILIYOR (Google'ın resmi test reklamları).
/// AdMob hesabı açıldığında admob.google.com'dan alınan gerçek
/// kimliklerle değiştirilecek: hem aşağıdaki banner kimliği hem de
/// AndroidManifest.xml'deki APPLICATION_ID.
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class Ads {
  /// Google'ın resmi test banner kimliği.
  static const bannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // Reklam başlatılamazsa uygulama reklamsız çalışmaya devam eder.
    }
  }
}

/// Alt banner. Yüklenemezse hiç yer kaplamaz.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: Ads.bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        width: double.infinity,
        height: _ad!.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: _ad!.size.width.toDouble(),
            height: _ad!.size.height.toDouble(),
            child: AdWidget(ad: _ad!),
          ),
        ),
      ),
    );
  }
}
