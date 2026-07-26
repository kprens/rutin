/// Ürün analitiği — dönüşüm hunisi ve retention ölçümü.
///
/// NEDEN VAR: Denetim öncesi uygulamada tek bir olay ölçümü yoktu. Paywall'ı
/// kaç kişinin gördüğü, hangi planı seçtiği, nerede vazgeçtiği, satın almanın
/// neden başarısız olduğu — hiçbiri bilinmiyordu. Ölçüm olmadan dönüşüm
/// iyileştirmesi tahmin yürütmekten ibarettir: bir değişikliğin işe yarayıp
/// yaramadığı asla anlaşılamaz.
///
/// TASARIM İLKELERİ (hepsi bilinçli):
///
///  1. **Asla çökmez, asla bloke etmez.** Bu proje açılış zincirindeki tek bir
///     korumasız `await` yüzünden iki kez "uygulama hiç açılmıyor" durumuna
///     düştü (bkz. main.dart). Analitik, ürünün EN ÖNEMSİZ parçasıdır; hiçbir
///     koşulda kullanıcı akışını yavaşlatamaz veya kıramaz. Tüm gönderim
///     arka planda, hatalar yutularak yapılır.
///
///  2. **Kişisel veri GÖNDERİLMEZ.** Rutin bir bağımlılık bırakma uygulaması.
///     Alışkanlık/bırakma adı, kullanıcı adı, e-posta, mektup metni, serbest
///     metin ASLA olay parametresi olamaz. [_sanitize] bunu kod düzeyinde
///     zorlar: yalnızca sayı, bool ve kısa/güvenli metinler geçer.
///
///  3. **Sağlayıcıdan bağımsız.** [AnalyticsSink] arayüzü sayesinde Supabase
///     yerine Firebase/PostHog/Amplitude'a geçmek tek bir sınıf yazmak
///     demektir; çağrı yerlerinin hiçbiri değişmez.
///
///  4. **Çevrimdışı dayanıklı.** Olaylar kuyruğa alınır, toplu gönderilir ve
///     gönderilemeyenler diske yazılır — uygulama kapansa bile kaybolmaz.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_info.dart';

/// Tek bir ölçüm olayı.
@immutable
class AnalyticsEvent {
  final String name;
  final Map<String, Object?> params;
  final DateTime at;

  const AnalyticsEvent(this.name, this.params, this.at);

  Map<String, dynamic> toJson() => {
        'name': name,
        'params': params,
        'at': at.toIso8601String(),
      };

  static AnalyticsEvent fromJson(Map<String, dynamic> j) => AnalyticsEvent(
        j['name'] as String,
        Map<String, Object?>.from(j['params'] as Map? ?? const {}),
        DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Olayların gönderileceği hedef. Sağlayıcı değiştirmek = bunu yeniden yazmak.
abstract class AnalyticsSink {
  /// Başarılıysa `true` döner. `false` dönerse olaylar kuyrukta kalır ve
  /// bir sonraki denemede tekrar gönderilir.
  Future<bool> send(String installId, List<AnalyticsEvent> batch);
}

/// Analitik kapalıyken (kullanıcı devre dışı bıraktı ya da backend yok).
class NoopAnalyticsSink implements AnalyticsSink {
  const NoopAnalyticsSink();

  @override
  Future<bool> send(String installId, List<AnalyticsEvent> batch) async => true;
}

/// Varsayılan hedef: kendi Supabase projemizdeki `analytics_events` tablosu
/// (bkz. supabase_analytics.sql).
class SupabaseAnalyticsSink implements AnalyticsSink {
  const SupabaseAnalyticsSink();

  @override
  Future<bool> send(String installId, List<AnalyticsEvent> batch) async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final rows = batch
          .map((e) => {
                'install_id': installId,
                'user_id': uid,
                'name': e.name,
                'params': e.params,
                'app_version': kAppVersion,
                'platform': defaultTargetPlatform.name,
                'client_ts': e.at.toIso8601String(),
              })
          .toList();
      await client
          .from('analytics_events')
          .insert(rows)
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      // Ağ yok / tablo kurulu değil / RLS reddetti. Olaylar kuyrukta kalır.
      return false;
    }
  }
}

class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  static const _installIdKey = 'analyticsInstallId';
  static const _queueKey = 'analyticsQueue';
  static const _enabledKey = 'analyticsEnabled';

  /// Kuyruk üst sınırı. Aşılırsa EN ESKİ olaylar düşer: analitik uğruna
  /// kullanıcının diskini şişirmek kabul edilemez.
  static const _maxQueue = 500;

  /// Bu sayıya ulaşınca kendiliğinden gönderilir.
  static const _batchSize = 20;

  /// Periyodik gönderim aralığı.
  static const _flushInterval = Duration(seconds: 30);

  AnalyticsSink _sink = const NoopAnalyticsSink();
  String _installId = '';
  final List<AnalyticsEvent> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  bool _ready = false;

  /// Kullanıcı analitiği kapatabilir (bkz. Ayarlar → Veri & Gizlilik).
  /// Kapalıyken hiçbir olay toplanmaz ve kuyruk temizlenir.
  bool enabled = true;

  /// Uygulama açılışında bir kez çağrılır. HİÇBİR koşulda fırlatmaz.
  ///
  /// [sink] verilmezse ve Supabase yapılandırılmışsa Supabase kullanılır;
  /// yapılandırılmamışsa analitik sessizce devre dışı kalır.
  Future<void> init({AnalyticsSink? sink, bool backendAvailable = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      enabled = prefs.getBool(_enabledKey) ?? true;

      _installId = prefs.getString(_installIdKey) ?? '';
      if (_installId.isEmpty) {
        _installId = _newInstallId();
        await prefs.setString(_installIdKey, _installId);
      }

      _sink = sink ??
          (backendAvailable
              ? const SupabaseAnalyticsSink()
              : const NoopAnalyticsSink());

      // Önceki oturumdan gönderilememiş olaylar.
      final raw = prefs.getStringList(_queueKey) ?? const [];
      for (final s in raw) {
        try {
          _queue.add(
              AnalyticsEvent.fromJson(jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {
          // Bozuk kayıt atlanır.
        }
      }

      _ready = true;
      _timer?.cancel();
      _timer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
    } catch (_) {
      // Analitik kurulamadı — uygulama normal çalışmaya devam eder.
      _ready = false;
    }
  }

  /// Cihaz başına anonim kimlik. Reklam kimliği DEĞİL, kişisel veri DEĞİL;
  /// yalnızca aynı cihazın huni adımlarını birbirine bağlar.
  String _newInstallId() {
    final rnd = Random.secure();
    String hex(int n) => List.generate(
        n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + rnd.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  /// Bir olay kaydeder. Senkron ve ucuzdur; gönderim arka planda olur.
  void log(String name, [Map<String, Object?> params = const {}]) {
    if (!enabled || !_ready) return;
    try {
      _queue.add(AnalyticsEvent(name, _sanitize(params), DateTime.now()));
      while (_queue.length > _maxQueue) {
        _queue.removeAt(0);
      }
      if (_queue.length >= _batchSize) unawaited(flush());
    } catch (_) {
      // Ölçüm hiçbir zaman akışı bozmaz.
    }
  }

  /// Ekran görüntüleme kısayolu.
  void screen(String name) => log('screen_view', {'screen': name});

  /// KİŞİSEL VERİ FİLTRESİ.
  ///
  /// Yalnızca sayı, bool ve KISA metinler geçer. Uzun metin, serbest kullanıcı
  /// girdisi olma ihtimali yüksek olduğu için (alışkanlık adı, mektup, isim)
  /// tamamen düşürülür. Bu, "yanlışlıkla hassas veri gönderme" hatasını
  /// tek tek çağrı yerlerine güvenmek yerine merkezî olarak imkânsız kılar.
  static Map<String, Object?> _sanitize(Map<String, Object?> params) {
    final out = <String, Object?>{};
    for (final e in params.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is num || v is bool) {
        out[e.key] = v;
      } else if (v is String) {
        // 40 karakteri aşan ya da boşluk içeren değerler serbest metin
        // sayılır ve GÖNDERİLMEZ. Olay parametreleri enum gibi olmalı
        // ('yearly', 'store_unavailable', 'home').
        if (v.isNotEmpty && v.length <= 40 && !v.contains(' ')) {
          out[e.key] = v;
        }
      }
      // Diğer tüm tipler (liste, map, nesne) bilinçli olarak düşürülür.
    }
    return out;
  }

  /// Kuyruğu göndermeye çalışır. Başarısızsa olaylar diske yazılır.
  Future<void> flush() async {
    if (!_ready || _flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      final batch = List<AnalyticsEvent>.from(_queue);
      final ok = await _sink.send(_installId, batch);
      if (ok) {
        _queue.removeRange(0, min(batch.length, _queue.length));
        await _persist();
      } else {
        // Gönderilemedi — kalıcılaştır ki uygulama kapansa da kaybolmasın.
        await _persist();
      }
    } catch (_) {
      // Yut.
    } finally {
      _flushing = false;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_queue.isEmpty) {
        await prefs.remove(_queueKey);
        return;
      }
      await prefs.setStringList(
          _queueKey, _queue.map((e) => jsonEncode(e.toJson())).toList());
    } catch (_) {
      // Disk yazılamadı.
    }
  }

  /// Kullanıcı analitiği açar/kapatır. Kapatınca bekleyen olaylar da silinir.
  Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      if (!value) {
        _queue.clear();
        await prefs.remove(_queueKey);
      }
    } catch (_) {
      // Tercih kaydedilemedi.
    }
  }

  /// Uygulama arka plana alınırken çağrılır — oturum verisi kaybolmasın.
  Future<void> onPause() => flush();

  @visibleForTesting
  List<AnalyticsEvent> get pendingForTest => List.unmodifiable(_queue);

  @visibleForTesting
  Future<void> resetForTest(AnalyticsSink sink) async {
    _queue.clear();
    _sink = sink;
    _installId = 'test-install';
    _ready = true;
    enabled = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// Olay adları — TEK KAYNAK.
///
/// Serbest string yerine sabit kullanmak, yazım hatası yüzünden huninin
/// sessizce kopmasını engeller ("paywall_view" vs "paywall_viewed" gibi bir
/// fark, tüm dönüşüm raporunu boşa çıkarır).
abstract final class Ev {
  // ---- Huni ----
  static const appOpen = 'app_open';
  static const onboardingStart = 'onboarding_start';
  static const onboardingStep = 'onboarding_step';
  static const onboardingSkip = 'onboarding_skip';
  static const onboardingComplete = 'onboarding_complete';

  static const authStart = 'auth_start';
  static const authSuccess = 'auth_success';
  static const authFail = 'auth_fail';

  static const paywallView = 'paywall_view';
  static const paywallDismiss = 'paywall_dismiss';
  static const planSelect = 'plan_select';
  static const purchaseStart = 'purchase_start';
  static const purchaseSuccess = 'purchase_success';
  static const purchaseFail = 'purchase_fail';
  static const purchaseCancel = 'purchase_cancel';
  static const purchaseRestore = 'purchase_restore';

  // ---- Reklam / geçici Pro ----
  static const rewardedStart = 'rewarded_start';
  static const rewardedGranted = 'rewarded_granted';
  static const rewardedUnavailable = 'rewarded_unavailable';

  // ---- Etkileşim / retention ----
  static const habitCheck = 'habit_check';
  static const streakRelapse = 'streak_relapse';
  static const crisisOpen = 'crisis_open';
  static const milestoneReached = 'milestone_reached';
}
