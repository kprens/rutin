/// AdMob reklamları — Pro (veya geçici Pro) kullanıcılarda gösterilmez.
///
/// Üç reklam biçimi:
///   1. Banner  → alt navigasyonun üstünde sürekli açık küçük şerit.
///   2. Interstitial → tam ekran; YALNIZCA doğal geçiş anlarında (sekme
///      değişimi) ve KATI frekans sınırıyla. Asla açılışta, asla bir
///      aksiyonun ortasında (Google Play politikası + kullanıcı deneyimi).
///   3. Rewarded → kullanıcının İSTEYEREK izlediği ödüllü reklam; karşılığında
///      geçici (4 saat) Pro erişimi açılır (bkz. AppState.grantProTrial).
///
/// Tüm birim kimlikleri build-time'da `--dart-define` ile verilir; verilmezse
/// Google'ın resmi TEST kimliklerine düşer (yalnızca geliştirme için güvenli;
/// mağazaya bu haliyle GÖNDERİLMEMELİ — build_release.sh gerçek kimlikleri
/// enjekte eder).
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'analytics.dart';

class Ads {
  // ---------------- Banner ----------------
  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const _bannerGeneric =
      String.fromEnvironment('ADMOB_BANNER_UNIT_ID', defaultValue: '');

  static String get bannerUnitId {
    if (_bannerGeneric.isNotEmpty) return _bannerGeneric;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _bannerIos
        : _bannerAndroid;
  }

  // ---------------- Interstitial ----------------
  static const _interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  static String get interstitialUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _interstitialIos
          : _interstitialAndroid;

  // ---------------- Rewarded ----------------
  static const _rewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _rewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static String get rewardedUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _rewardedIos
          : _rewardedAndroid;

  /// Uygulama açılış zamanı — interstitial "ısınma" (ilk N saniye reklam yok)
  /// için kullanılır.
  static final DateTime appStart = DateTime.now();

  /// AVRUPA EKONOMİK ALANI / BK KULLANICILARI İÇİN RIZA (UMP).
  ///
  /// Google'ın "EU user consent policy"si, EEA ve BK'daki kullanıcılara
  /// kişiselleştirilmiş reklam gösterilmeden önce geçerli bir rıza alınmasını
  /// ZORUNLU kılar. Bu akış uygulamada hiç yoktu: EEA kullanıcılarına rıza
  /// sorulmadan reklam isteniyordu. Bunun iki sonucu var — GDPR uyumsuzluğu
  /// ve Google'ın reklam yayınını askıya alma / hesabı kısıtlama riski.
  ///
  /// UMP `google_mobile_ads` paketinin İÇİNDE geliyor; yeni bir bağımlılık
  /// gerekmiyor. Form yalnızca gerektiği bölgede gösterilir — Türkiye gibi
  /// kapsam dışı bölgelerdeki kullanıcı hiçbir ek ekran görmez.
  ///
  /// Rıza akışı başarısız olursa reklamlar yine de (kişiselleştirilmemiş
  /// olarak) istenir; uygulama hiçbir koşulda burada takılmaz.
  static Future<void> _requestConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {
          // Form gösterilemedi; kişiselleştirilmemiş reklamla devam.
        }
        if (!completer.isCompleted) completer.complete();
      },
      (_) {
        // Rıza bilgisi güncellenemedi (ağ yok vb.) — akışı bekletme.
        if (!completer.isCompleted) completer.complete();
      },
    );
    // UMP hiç yanıt vermezse reklam katmanı boot'u bloke etmemeli.
    await completer.future.timeout(const Duration(seconds: 6),
        onTimeout: () {});
  }

  static Future<void> init() async {
    try {
      // Rıza ÖNCE alınır: reklam isteği rıza durumundan sonra yapılmalı.
      await _requestConsent();
      await MobileAds.instance.initialize();
      Interstitials.instance.preload();
      Rewarded.instance.preload();
    } catch (_) {
      // Reklam başlatılamazsa uygulama reklamsız çalışmaya devam eder.
    }
  }

  /// APP TRACKING TRANSPARENCY (iOS 14.5+).
  ///
  /// `Info.plist`'te `NSUserTrackingUsageDescription` metni zaten vardı ama
  /// kodda ATT hiç istenmiyordu. Sonuç: iOS'ta IDFA'ya asla erişilemiyor,
  /// dolayısıyla TÜM reklamlar kişiselleştirilmemiş olarak sunuluyor ve eCPM
  /// belirgin biçimde düşük kalıyor. Bu doğrudan gelir kaybı.
  ///
  /// ZAMANLAMA — bilinçli olarak açılışta DEĞİL:
  /// Sistem bu diyaloğu kullanıcı başına YALNIZCA BİR KEZ gösterir; reddedilen
  /// izin uygulama içinden bir daha sorulamaz (kullanıcı Ayarlar'dan açmalı).
  /// Bu yüzden tek atış, kullanıcı uygulamanın ne işe yaradığını gördükten
  /// SONRA kullanılmalı. Soğuk açılışta bağlamsız sorulması, bildirim
  /// izninde olduğu gibi (bkz. main.dart) ret oranını yükseltirdi.
  /// Çağrı yeri: [RootShell] — yani onboarding ve giriş tamamlandıktan sonra.
  ///
  /// Android ve diğer platformlarda no-op: ATT yalnızca Apple platformlarında
  /// vardır.
  ///
  /// Hipotez (ölçülmedi): izni ikinci oturuma ertelemek onay oranını daha da
  /// artırabilir. Şu anki kurgu, mevcut kullanıcıları da kapsaması için
  /// RootShell'e bağlı; ölçüm için `att_*` olaylarına bakılabilir.
  static Future<void> ensureTrackingRequested() async {
    // `dart:io` Platform DEĞİL: bu proje web'i de hedefliyor (web/ dizini var)
    // ve dart:io orada derlenmez. `kIsWeb` kontrolü de şart — web'de
    // defaultTargetPlatform, tarayıcının çalıştığı CİHAZI döndürür, yani
    // iPhone'daki Safari'de TargetPlatform.iOS gelir ama ATT diye bir şey yoktur.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      // Daha önce karar verilmişse sistem diyaloğu zaten göstermez;
      // gereksiz çağrı yapmadan durumu ölç ve çık.
      if (status != TrackingStatus.notDetermined) {
        Analytics.instance.log(Ev.attStatus, {'status': status.name});
        return;
      }
      Analytics.instance.log(Ev.attPrompt);
      final result =
          await AppTrackingTransparency.requestTrackingAuthorization();
      Analytics.instance.log(Ev.attStatus, {'status': result.name});
    } catch (_) {
      // ATT sorulamadı (eski iOS, simülatör tuhaflığı vb.) — reklamlar
      // kişiselleştirilmemiş olarak çalışmaya devam eder.
    }
  }

  /// Kullanıcının rıza tercihini sonradan değiştirebilmesi için (GDPR'ın
  /// "rızayı geri çekme" hakkı). Yalnızca gereken bölgelerde anlamlıdır;
  /// Ayarlar ekranı bu bayrağa göre satırı gösterir/gizler.
  static Future<bool> privacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Rıza tercihlerini yeniden gösterir.
  static Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {
      // Form açılamadı.
    }
  }
}

/// Alt banner. Yüklenemezse hiç yer kaplamaz.
///
/// Uygulama arka plandan öne her döndüğünde eski reklamı imha edip TAZE bir
/// reklam ister. Bazı düşük kaliteli reklam kreatifleri arka planda kendi
/// kendine tarayıcıya yönlendirme yapabiliyor ("forced redirect" — reklama
/// hiç dokunmadan, uygulamaya her dönüşte tekrar tekrar bir siteye atılma).
/// Eski reklam örneğini canlı tutmayıp her resume'da yenisiyle değiştirmek bu
/// döngüyü kırar; ayrıca AdMob konsolunda ilgili reklam ağı/kategorisini
/// engellemek (Bloklama denetimleri) kalıcı çözüm için önerilir.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> with WidgetsBindingObserver {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLoad();
  }

  void _startLoad() {
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

  /// Eskiyi ANINDA ekrandan kaldırır (setState), sonra imha edip yeni bir
  /// reklam ister — resume anında stale/kötü niyetli reklamın bir an bile
  /// ekranda/hafızada asılı kalmaması için.
  void _reloadFreshAd() {
    final oldAd = _ad;
    setState(() {
      _ad = null;
      _loaded = false;
    });
    oldAd?.dispose();
    _startLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reloadFreshAd();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

/// Frekans sınırlı tam ekran (interstitial) reklam yöneticisi.
///
/// Politika + deneyim kuralları (hepsi burada, tek yerde):
///   • Yalnızca Pro OLMAYAN kullanıcıya.
///   • Açılıştan sonra ilk [_warmup] boyunca hiç gösterilmez.
///   • İki reklam arası en az [_cooldown] beklenir.
///   • Oturum başına en fazla [_maxPerSession] reklam.
///   • Yalnızca doğal geçiş anında çağrılır (sekme değişimi) — asla bir
///     aksiyonun ortasında.
class Interstitials {
  Interstitials._();
  static final Interstitials instance = Interstitials._();

  // Frekans sınırları, belirlenen "günde en fazla 2–3 tam ekran reklam"
  // hedefine göre ayarlandı. Sekmeler arası artık KAYDIRARAK da geçiliyor
  // (bkz. root_shell.dart PageView) — kaydırma, sekmeye dokunmaya kıyasla
  // çok daha sık ve rastgele bir hareket olduğu için eski değerler
  // (3 dk / oturum başına 5) kullanıcıyı gereğinden fazla reklama maruz
  // bırakırdı. Reklamdan rahatsız olan kullanıcı düşük puan verir; bu da
  // uzun vadede reklam gelirinden daha pahalıya mal olur.
  static const _warmup = Duration(seconds: 90);
  static const _cooldown = Duration(minutes: 6);
  static const _maxPerSession = 3;

  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;
  DateTime? _lastShown;
  int _shownThisSession = 0;

  void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: Ads.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  bool get _withinCooldown =>
      _lastShown != null && DateTime.now().difference(_lastShown!) < _cooldown;

  /// Doğal bir geçiş anında çağrılır. Tüm kurallar sağlanıyorsa reklamı
  /// gösterir; değilse sessizce hiçbir şey yapmaz (ve bir sonraki için
  /// önceden yükler).
  void maybeShow({required bool isPro}) {
    if (isPro || _showing) return;
    if (DateTime.now().difference(Ads.appStart) < _warmup) return;
    if (_shownThisSession >= _maxPerSession) return;
    if (_withinCooldown) return;
    final ad = _ad;
    if (ad == null) {
      preload();
      return;
    }
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _showing = false;
        _lastShown = DateTime.now();
        _shownThisSession++;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _ad = null;
        _showing = false;
        preload();
      },
    );
    ad.show();
  }
}

/// Ödüllü (rewarded) reklam. Kullanıcı isteyerek izler; tamamlarsa [onReward]
/// çağrılır (geçici Pro açmak için). Yükleme/başarısızlık durumları için
/// callback'ler döner ki UI kullanıcıyı bilgilendirebilsin.
class Rewarded {
  Rewarded._();
  static final Rewarded instance = Rewarded._();

  RewardedAd? _ad;
  bool _loading = false;

  void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: Ads.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  bool get isReady => _ad != null;

  /// Reklamı gösterir. Kullanıcı ödülü hak ederse [onReward] bir kez çağrılır.
  /// Reklam hazır değilse [onUnavailable] çağrılır (ve arka planda yüklenir).
  void show({
    required VoidCallback onReward,
    VoidCallback? onUnavailable,
  }) {
    final ad = _ad;
    if (ad == null) {
      preload();
      onUnavailable?.call();
      return;
    }
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _ad = null;
        preload();
        if (!earned) onUnavailable?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, __) {
      earned = true;
      onReward();
    });
  }
}
