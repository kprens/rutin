/// Uygulama durumu (state) ve iş mantığı.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics.dart';
import 'auth.dart';
import 'friends.dart';
import 'home_widget_service.dart' as hw;
import 'iap.dart';
import 'insights.dart';
import 'l10n.dart';
import 'models.dart';
import 'notifications.dart';
import 'repository.dart';
import 'theme.dart';

String todayKey([DateTime? d]) {
  final n = d ?? DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// 0 = Pazartesi ... 6 = Pazar
int mondayIndex(DateTime d) => (d.weekday - 1) % 7;

const milestones = [1, 3, 7, 14, 30, 90, 180, 365];

class AppState extends ChangeNotifier {
  // ÖNEMLİ: artık `final` değil — hesap girişi/çıkışında Local↔Cloud arası
  // geçiş yapabilmek için (bkz. boot/onSignedIn/signOut).
  Repository repo;
  final NotificationService notifications;

  List<Streak> streaks = [];
  List<TaskItem> tasks = [];
  Map<String, List<int>> doneByDate = {}; // 'yyyy-MM-dd' -> [taskId]
  Map<String, int> waterByDate = {}; // 'yyyy-MM-dd' -> bardak
  List<WeeklyItem> weekly = [];
  List<EventItem> events = [];
  WaterState water = WaterState(date: todayKey());

  // Pro / tema
  // Varsayılan: Pro kullanıcılar için 'Gece Yarısı' (pro tema), ücretsiz
  // kullanıcılar için 'Beyaz' (temiz/minimal ücretsiz tema — turuncu 'Alev'
  // hakkında olumsuz kullanıcı yorumları üzerine varsayılandan çıkarıldı;
  // Alev, Okyanus ve diğerleri hâlâ tema listesinde seçenek olarak duruyor)
  // — bkz. load() ve theme.dart (ThemeSpec.pro). Bu alan sadece "hiç veri
  // yokken" (ilk açılış, isPro henüz bilinmiyor/false) kullanılır; load()
  // gerçek isPro'ya göre ezer.
  String themeId = 'beyaz';

  /// KALICI Pro — satın alma ile açılır (bkz. activatePro). Ödüllü reklamla
  /// açılan GEÇİCİ Pro'dan ayrıdır; kalıcı olan buraya, geçici olan
  /// [proTrialUntilMs]'e yazılır.
  bool isPro = false;

  /// Ödüllü reklamla açılan geçici Pro'nun bitiş zamanı (epoch ms). null ise
  /// aktif deneme yok. Erişim kontrolü için [hasPro] kullanılmalı — [isPro]
  /// tek başına geçici erişimi görmez.
  int? proTrialUntilMs;

  /// Varsayılan AÇIK mod. Her tema hem açık hem koyu palete sahiptir
  /// (bkz. theme.dart) ve bu bayrak hangisinin kullanılacağını belirler.
  /// Varsayılan tema 'beyaz' yapıldığında bu alan hâlâ `true` (koyu) idi;
  /// yani yeni kullanıcı "Beyaz" temayı seçili görüyor ama ekranda onun
  /// KOYU paleti (#0F1115, neredeyse siyah) çiziliyordu — istenen beyaz
  /// görünüm hiç ortaya çıkmıyordu. Mevcut kullanıcılar kendi kayıtlı
  /// tercihlerini korur (load() yalnızca kayıt yoksa bu varsayılana düşer).
  bool darkMode = false;

  // Kullanıcı profili (yeni arayüz)
  String userName = '';
  int? createdAtMs; // hesabın oluşturulma zamanı ("Member since")

  // Su kayıt defteri: 'yyyy-MM-dd' -> [ {ml, time} ]
  Map<String, List<WaterLogEntry>> waterLog = {};

  /// Kriz/nüks anlarında toplanan tek dokunuşluk bağlam kayıtları
  /// (bkz. TriggerEntry). Faz 3'ün (Risk Penceresi, Tetikleyici Haritası)
  /// tek veri kaynağı budur.
  List<TriggerEntry> triggerLog = [];

  // Ayarlar (yeni arayüz kalıcı toggle'ları)
  bool pushNotifications = true;
  bool dailyReminders = true;
  bool sounds = false;
  bool haptics = true;
  bool weekStartsMonday = true;

  /// Dil override: null = cihaz dili, 'tr' / 'en' = manuel seçim.
  String? localeOverride;

  // Retention
  bool onboarded = false;
  List<String> checklistFullDays = []; // listenin tamamlandığı günler
  Map<String, int> celebrated = {}; // streakId -> kutlanan son milestone

  // Sosyal: arkadaşlarla paylaşılan streak id'leri
  Set<int> sharedStreakIds = {};

  // ---------- Arkadaşlar / Sorumluluk Ortağı ----------
  // Bkz. friends.dart. Bulut olmadan (LocalFriendsService) bu alanlar
  // boş kalır — ekran normal çalışmaya devam eder, sadece arkadaş
  // eklenemez.
  String? myFriendCode;
  List<FriendshipView> friendships = [];
  Map<String, List<SharedStreakSummary>> _sharedByFriend = {};
  bool friendsLoading = false;
  String? friendsError;

  List<FriendshipView> get incomingRequests => friendships
      .where((f) => f.status == FriendshipStatus.pending && f.incoming)
      .toList();
  List<FriendshipView> get outgoingRequests => friendships
      .where((f) => f.status == FriendshipStatus.pending && !f.incoming)
      .toList();
  List<FriendshipView> get acceptedFriends => friendships
      .where((f) => f.status == FriendshipStatus.accepted)
      .toList();

  List<SharedStreakSummary> sharedStreaksOf(String friendId) =>
      _sharedByFriend[friendId] ?? const [];

  /// Arkadaş ekranı açıldığında çağrılır: profilimi (ve friend_code'umu)
  /// garantiye alır, arkadaşlık kayıtlarını ve kabul edilen arkadaşların
  /// paylaştığı streak'leri yükler.
  Future<void> loadFriends() async {
    if (!supabaseConfigured) return;
    friendsLoading = true;
    friendsError = null;
    notifyListeners();
    try {
      myFriendCode = await friendsService.ensureProfile(userName);
      friendships = await friendsService.loadFriendships();
      final acceptedIds = acceptedFriends.map((f) => f.other.id).toList();
      final shared = await friendsService.loadSharedStreaks(acceptedIds);
      final grouped = <String, List<SharedStreakSummary>>{};
      for (final s in shared) {
        grouped.putIfAbsent(s.userId, () => []).add(s);
      }
      _sharedByFriend = grouped;
    } catch (_) {
      friendsError =
          t('Arkadaşlar yüklenemedi. Tekrar dene.', 'Couldn\'t load friends. Try again.');
    }
    friendsLoading = false;
    notifyListeners();
  }

  /// Bir arkadaşlık kodu ile istek gönderir. Başarılıysa null döner ve
  /// listeyi tazeler; değilse kullanıcıya gösterilecek hatayı döndürür.
  Future<String?> addFriendByCode(String code) async {
    final err = await friendsService.sendRequestByCode(code);
    if (err == null) await loadFriends();
    return err;
  }

  Future<void> respondToFriendRequest(FriendshipView f,
      {required bool accept}) async {
    await friendsService.respondToRequest(f.id, accept: accept);
    await loadFriends();
  }

  Future<void> removeFriend(FriendshipView f) async {
    await friendsService.removeFriendship(f.id);
    await loadFriends();
  }

  // ---------- Panik sinyali (sorumluluk ortağı) ----------

  /// Arkadaşlardan gelen, son 24 saatlik "zorlanıyorum" sinyalleri.
  List<PanicSignal> panicSignals = [];

  /// Kriz anında arkadaşlara sinyal gönderir.
  ///
  /// DÜRÜSTLÜK NOTU: Anlık push bildirimi göndermez — arkadaş uygulamayı
  /// bir sonraki açışında görür. Arayüz bunu kullanıcıya açıkça söyler;
  /// "arkadaşın anında haberdar olacak" gibi tutulamayacak bir söz
  /// vermek, tam da güvenin en kritik olduğu anda yalan söylemek olurdu.
  Future<bool> sendPanicSignal(String streakName) =>
      friendsService.sendPanicSignal(streakName);

  Future<void> loadPanicSignals() async {
    if (!supabaseConfigured) return;
    try {
      panicSignals = await friendsService.loadPanicSignals();
      notifyListeners();
    } catch (_) {
      // Yok sayılır — arkadaş ekranı normal çalışmaya devam eder.
    }
  }

  Future<void> acknowledgePanic(PanicSignal signal) async {
    await friendsService.acknowledgePanic(signal.id);
    await loadPanicSignals();
  }

  // Mağaza puanı yalnızca bir kez istenir
  bool reviewAsked = false;

  void markReviewAsked() {
    reviewAsked = true;
    _save();
  }

  void toggleSharedStreak(int id) {
    if (sharedStreakIds.contains(id)) {
      sharedStreakIds.remove(id);
    } else {
      sharedStreakIds.add(id);
    }
    _save();
    notifyListeners();
    // Sunucuyla senkronla (backend yoksa no-op). Streak silinmiş olabilir
    // (paylaşımı kaldırırken) — bulunamazsa senkronizasyonu atla.
    final matches = streaks.where((s) => s.id == id);
    if (matches.isNotEmpty) {
      friendsService.syncSharedStreak(matches.first,
          shared: sharedStreakIds.contains(id));
    }
  }

  /// KALDIRILDI: Ücretsiz sürümdeki bırakma (streak) sayısı limiti.
  ///
  /// Eskiden 2 ile sınırlıydı. Kaldırıldı çünkü:
  ///  • Bağımlılıklar kümelenir — sigarayı bırakan kişi genelde aynı anda
  ///    alkolü/şekeri de bırakmaya çalışır. Üçüncüde duvara toslamak,
  ///    kullanıcıyı en kırılgan anında cezalandırmaktır.
  ///  • Bu tip "sayı kısıtı", satın almaya zorlamaktan başka bir amaca
  ///    hizmet etmeyen yapay bir engeldi; ürettiği gelir minimal, ürettiği
  ///    hayal kırıklığı büyüktü.
  ///  • Premium artık "kaç tane takip edebildiğini" değil, "o takiplerin ne
  ///    anlama geldiğini" (içgörü, öngörü, koçluk) satıyor.
  /// Alan, eski kayıtlarla/koşullarla uyumluluk için tutulmuyor; tamamen
  /// kaldırıldı ve [canAddStreak] her zaman true.

  /// Aktif bir ödüllü-reklam Pro denemesi var mı (süresi dolmamış).
  bool get proTrialActive =>
      proTrialUntilMs != null &&
      DateTime.now().millisecondsSinceEpoch < proTrialUntilMs!;

  /// EFEKTİF Pro erişimi: kalıcı satın alma VEYA aktif geçici deneme.
  /// Reklam gizleme, kilitli tema/özellik gibi tüm erişim kontrolleri bunu
  /// kullanmalı (çıplak [isPro] yerine).
  bool get hasPro => isPro || proTrialActive;

  /// Aktif denemenin bitişine kalan süre (yoksa null).
  Duration? get proTrialRemaining => proTrialActive
      ? Duration(
          milliseconds:
              proTrialUntilMs! - DateTime.now().millisecondsSinceEpoch)
      : null;

  /// Artık herkes sınırsız bırakma takibi ekleyebilir (bkz. yukarıdaki not).
  bool get canAddStreak => true;

  /// Kullanıcının uygulamayı ilk açtığından bu yana geçen gün sayısı.
  /// Premium tanıtımlarının zamanlamasında kullanılır: kullanıcı henüz
  /// hiçbir başarı yaşamadan (ilk günlerde) satış yapmak hem dönüşümü
  /// düşürür hem güveni zedeler. Tanıtımlar ancak kullanıcı gerçek bir
  /// değer gördükten sonra gösterilir (bkz. [showPremiumPromos]).
  int get daysSinceInstall {
    final ms = createdAtMs;
    if (ms == null) return 0;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms))
        .inDays;
  }

  /// Premium TANITIM kartları (ekranlardaki "Pro'ya geç" önerileri)
  /// gösterilsin mi. Ödeme ekranının KENDİSİ her zaman erişilebilir kalır —
  /// burada engellenen yalnızca davetsiz satış mesajlarıdır.
  ///
  /// 7 gün: kullanıcı ilk haftasını tamamlayıp ilk gerçek kazanımını
  /// (seri, kazanılan para, atlatılan kriz) yaşadıktan sonra teklif çok daha
  /// yüksek dönüşür ve rahatsız edici hissettirmez.
  bool get showPremiumPromos => !hasPro && daysSinceInstall >= 7;

  AppState({required this.repo, required this.notifications});

  /// Ödüllü reklam izlendiğinde çağrılır: [duration] kadar (varsayılan 4 saat)
  /// geçici Pro açar. Zaten kalıcı Pro ise hiçbir şey yapmaz. Aktif bir deneme
  /// varsa kalan süreye EKLEMEZ, yeni 4 saatlik pencereyi baştan başlatır
  /// (izlemeyi sık tekrarlamaya teşvik = daha çok reklam geliri).
  void grantProTrial([Duration duration = const Duration(hours: 4)]) {
    if (isPro) return;
    proTrialUntilMs =
        DateTime.now().add(duration).millisecondsSinceEpoch;
    _scheduleProTrialExpiry();
    _save();
    notifyListeners();
  }

  Timer? _proTrialTimer;

  /// Deneme bitiş anında bir kez [notifyListeners] tetikler ki reklam/kilit
  /// UI'ı anında güncellensin (aksi halde süre dolsa bile ekran bir sonraki
  /// yeniden çizime kadar Pro görünmeye devam eder). load() ve grantProTrial
  /// tarafından kurulur.
  void _scheduleProTrialExpiry() {
    _proTrialTimer?.cancel();
    if (!proTrialActive) return;
    _proTrialTimer = Timer(proTrialRemaining!, () {
      notifyListeners();
    });
  }

  /// AppState uygulama ömrü boyunca yaşayan tek bir örnek olsa da, testlerde
  /// ve olası yeniden oluşturma senaryolarında zamanlayıcının açıkta kalıp
  /// atılmış (disposed) bir nesne üzerinde notifyListeners çağırmasını
  /// önlemek için iptal edilir.
  @override
  void dispose() {
    _proTrialTimer?.cancel();
    _proTrialTimer = null;
    super.dispose();
  }

  void setTheme(String id) {
    themeId = id;
    currentTheme = themeById(id);
    _save();
    notifyListeners();
  }

  /// Açık/koyu mod tercihini değiştirir. RC (yeni arayüz) ve MaterialApp'ın
  /// themeMode'u bu değere göre güncellenir.
  void setDarkMode(bool v) {
    darkMode = v;
    useDarkPalette = v;
    _save();
    notifyListeners();
  }

  /// Şimdilik test modu — Google Play Billing bağlandığında
  /// satın alma doğrulamasıyla değiştirilecek.
  void activatePro() {
    isPro = true;
    _save();
    notifyListeners();
  }

  // ---------- Yükleme / kaydetme ----------

  /// Kalıcı veriyi (yerel ya da bulut) belleğe yükler.
  ///
  /// TÜM ayrıştırma bir try/catch içindedir. Buradaki her satır ham JSON
  /// üzerinde tip dönüşümü (`as List`, `as int`, `as String`...) yapıyor;
  /// tek bir bozuk/eski biçimli alan bile istisna fırlatır. Bu fonksiyon
  /// `boot()` → `main()` zincirinde AWAIT edildiği için, korumasız haliyle
  /// böyle bir istisna `runApp`'e hiç ulaşılmamasına — yani kullanıcının
  /// uygulamayı BİR DAHA HİÇ AÇAMAMASINA — yol açardı. Üstelik bozuk veri
  /// buluttan geldiyse (başka bir cihaz/eski sürüm yazmışsa) uygulamayı
  /// silip yeniden kurmak bile çözmezdi. Ayrıştırma yarıda kalırsa o ana
  /// kadar okunanlar korunur, kalan alanlar varsayılanlarında kalır ve
  /// uygulama açılmaya devam eder.
  Future<void> load() async {
    LoadResult result;
    try {
      result = await repo.loadAll();
    } catch (_) {
      result = const LoadResult.failure();
    }
    _applyLoadedData(result.data);
    if (localeOverride != null) T.en = localeOverride == 'en';
    // Yeni veri yüklendi (veya hesap değişti) — eski hesabın/verinin seri
    // hesapları asla yeni veriye taşınmamalı.
    _invalidateStreakCache();
    currentTheme = themeById(themeId);
    useDarkPalette = darkMode;
    _scheduleProTrialExpiry();
    dailyRollover();
    // Bildirim kurulumu ASLA açılışı engellememeli. Gerçek örnek: bildirim
    // ikonu yanlış kaynak klasöründe olduğu için zonedSchedule
    // PlatformException(invalid_icon) fırlattı; bu istisna load() →
    // boot() → main() zincirinden yukarı çıkıp `runApp`'e hiç
    // ulaşılamamasına, yani uygulamanın AÇILMAMASINA yol açtı
    // (Sentry'de fatal olarak kaydedildi). Bildirimler çalışmasa bile
    // uygulama çalışmalı.
    try {
      await applyNotificationSettings();
    } catch (_) {
      // Bildirimler bu oturumda kurulamadı; uygulama normal devam eder.
    }
    await hw.applyPendingWidgetToggles(this);
    unawaited(hw.syncHomeWidget(this));
    notifyListeners();
  }

  /// Tek bir alanın bozuk olması KALAN alanların hiç yüklenmemesine yol
  /// açmamalı.
  ///
  /// Eskiden tüm ayrıştırma tek bir try/catch içindeydi: erken bir alanda
  /// fırlayan istisna (ör. buluta `double` olarak yazılmış `proTrialUntilMs`,
  /// ya da eski bir sürümün farklı biçimde yazdığı bir liste) ondan SONRA
  /// gelen `onboarded`, `userName`, `themeId`, `streaks` gibi alanların hiç
  /// okunmamasına yol açıyordu. Kullanıcı için bunun görüntüsü şuydu: tüm
  /// verisi kaybolmuş ve uygulama onu onboarding'e geri atmış. Artık her alan
  /// kendi başına korunuyor; bozuk bir alan yalnızca KENDİ varsayılanına
  /// düşer, diğerleri normal yüklenir.
  // Tip parametresi `V`: `T` bu projede yerelleştirme sınıfının adı
  // (bkz. l10n.dart) — jenerik ad olarak kullanılırsa onu gölgeler.
  V _field<V>(Map<String, dynamic> data, String key, V fallback,
      V Function(Object raw) parse) {
    final raw = data[key];
    if (raw == null) return fallback;
    try {
      return parse(raw);
    } catch (_) {
      return fallback;
    }
  }

  void _applyLoadedData(Map<String, dynamic>? data) {
    if (data == null) return;

    streaks = _field(data, 'streaks', <Streak>[], (raw) {
      return (raw as List)
          .map((e) => Streak.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    tasks = _field(data, 'tasks', <TaskItem>[], (raw) {
      return (raw as List)
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    doneByDate = _field(data, 'doneByDate', <String, List<int>>{}, (raw) {
      return (raw as Map).map((k, v) => MapEntry(
          k as String, (v as List).map((e) => (e as num).toInt()).toList()));
    });
    waterByDate = _field(data, 'waterByDate', <String, int>{}, (raw) {
      return (raw as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
    weekly = _field(data, 'weekly', <WeeklyItem>[], (raw) {
      return (raw as List)
          .map((e) => WeeklyItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    events = _field(data, 'events', <EventItem>[], (raw) {
      return (raw as List)
          .map((e) => EventItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    water = _field(data, 'water', water,
        (raw) => WaterState.fromJson(Map<String, dynamic>.from(raw as Map)));
    isPro = _field(data, 'isPro', false, (raw) => raw as bool);
    // JSON round-trip'te sayılar double'a dönüşebildiği için `as int` yerine
    // `num` üzerinden okunuyor.
    proTrialUntilMs =
        _field<int?>(data, 'proTrialUntilMs', null, (raw) => (raw as num).toInt());
    // Kaydedilmiş bir tema tercihi yoksa (yeni kullanıcı): Pro ise
    // 'Gece Yarısı' (pro tema), değilse 'Beyaz' (ücretsiz tema).
    // Kilitli/pro bir temayı ücretsiz kullanıcıya varsayılan olarak
    // vermemek için (bkz. themes_screen.dart'taki `locked` kontrolü).
    themeId =
        _field(data, 'themeId', isPro ? 'gece' : 'beyaz', (raw) => raw as String);
    // Kayıtlı tercih yoksa açık mod (varsayılan 'beyaz' temayla tutarlı).
    darkMode = _field(data, 'darkMode', false, (raw) => raw as bool);
    userName = _field(data, 'userName', '', (raw) => raw as String);
    createdAtMs =
        _field<int?>(data, 'createdAtMs', null, (raw) => (raw as num).toInt());
    waterLog =
        _field(data, 'waterLog', <String, List<WaterLogEntry>>{}, (raw) {
      return (raw as Map).map((k, v) => MapEntry(
          k as String,
          (v as List)
              .map((e) => WaterLogEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()));
    });
    pushNotifications =
        _field(data, 'pushNotifications', true, (raw) => raw as bool);
    dailyReminders = _field(data, 'dailyReminders', true, (raw) => raw as bool);
    sounds = _field(data, 'sounds', false, (raw) => raw as bool);
    haptics = _field(data, 'haptics', true, (raw) => raw as bool);
    weekStartsMonday =
        _field(data, 'weekStartsMonday', true, (raw) => raw as bool);
    localeOverride =
        _field<String?>(data, 'localeOverride', null, (raw) => raw as String);
    onboarded = _field(data, 'onboarded', false, (raw) => raw as bool);
    checklistFullDays = _field(data, 'checklistFullDays', <String>[],
        (raw) => (raw as List).map((e) => e as String).toList());
    celebrated = _field(data, 'celebrated', <String, int>{}, (raw) {
      return (raw as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
    sharedStreakIds = _field(data, 'sharedStreakIds', <int>{},
        (raw) => (raw as List).map((e) => (e as num).toInt()).toSet());
    reviewAsked = _field(data, 'reviewAsked', false, (raw) => raw as bool);
    weeklyReportsSeen =
        _field(data, 'weeklyReportsSeen', 0, (raw) => (raw as num).toInt());
    triggerLog = _field(data, 'triggerLog', <TriggerEntry>[], (raw) {
      return (raw as List)
          .map((e) => TriggerEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    adaptiveDismissed = _field(data, 'adaptiveDismissed', <String, int>{}, (raw) {
      return (raw as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    });
  }

  /// Bildirim ayarlarının (push + günlük hatırlatma) izin verdiği durumda
  /// su, takvim ve akşam özeti hatırlatıcılarını (yeniden) kurar; aksi halde
  /// hepsini iptal eder. Zamanlanan tüm hatırlatıcılar tek noktadan geçer.
  bool get remindersEnabled => pushNotifications && dailyReminders;

  /// Hatırlatıcıları kurar. Her tür AYRI AYRI korunur: birinin başarısız
  /// olması (izin yok, geçersiz ikon kaynağı, platform kanalı yok, tam
  /// zamanlı alarm izni reddedilmiş...) diğerlerinin hiç kurulmamasına yol
  /// açmamalı. Önceden tek bir `zonedSchedule` hatası tüm zinciri
  /// koparıyor ve uygulamanın açılışını engelliyordu.
  Future<void> applyNotificationSettings() async {
    Future<void> guard(Future<void> Function() task) async {
      try {
        await task();
      } catch (_) {
        // Bu hatırlatıcı türü kurulamadı; diğerleri denenmeye devam eder.
      }
    }

    if (remindersEnabled) {
      await guard(
          () => notifications.scheduleWaterReminders(water.intervalMinutes));
      await guard(
          () => notifications.scheduleCalendarReminders(weekly, events));
      await guard(() => notifications.scheduleWeeklyReport());
      await guard(_scheduleRiskWindowIfAny);
      try {
        _scheduleEvening();
      } catch (_) {}
    } else {
      await guard(() => notifications.cancelAllReminders());
    }
  }

  /// Kişisel risk penceresi tespit edildiyse proaktif uyarıyı kurar.
  ///
  /// Yalnızca Pro kullanıcıya: bu, İçgörüler ekranındaki analizin bildirim
  /// karşılığıdır ve o ekran Pro'dur. Ücretsiz kullanıcıya kilitli bir
  /// özelliğin bildirimini göndermek hem tutarsız hem rahatsız edici olurdu.
  ///
  /// Yeterli veri yoksa (bkz. kMinSamples) hiçbir şey kurulmaz — az veriyle
  /// yapılan yanlış bir uyarı, hiç uyarmamaktan kötüdür.
  Future<void> _scheduleRiskWindowIfAny() async {
    if (!hasPro || streaks.isEmpty) return;
    final ins = computeInsights(triggerLog);
    final w = ins.riskWindow;
    if (!ins.hasEnoughData || w == null) return;
    await notifications.scheduleRiskWindow(
      hourStart: w.hourStart,
      weekday: w.weekday,
      streakName: streaks.first.name,
    );
  }

  /// Tüm uygulama durumunun JSON haritası — hem [_save] (repo'ya yazma)
  /// hem de hesap geçişlerinde (bkz. boot/onSignedIn/signOut) kullanılır.
  Map<String, dynamic> _toMap() => {
        'streaks': streaks.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'doneByDate': doneByDate,
        'waterByDate': waterByDate,
        'weekly': weekly.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'water': water.toJson(),
        'waterLog': waterLog
            .map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'themeId': themeId,
        'isPro': isPro,
        'proTrialUntilMs': proTrialUntilMs,
        'darkMode': darkMode,
        'userName': userName,
        'createdAtMs': createdAtMs,
        'pushNotifications': pushNotifications,
        'dailyReminders': dailyReminders,
        'sounds': sounds,
        'haptics': haptics,
        'weekStartsMonday': weekStartsMonday,
        'localeOverride': localeOverride,
        'onboarded': onboarded,
        'checklistFullDays': checklistFullDays,
        'celebrated': celebrated,
        'sharedStreakIds': sharedStreakIds.toList(),
        'reviewAsked': reviewAsked,
        'weeklyReportsSeen': weeklyReportsSeen,
        'triggerLog': triggerLog.map((e) => e.toJson()).toList(),
        'adaptiveDismissed': adaptiveDismissed,
      };

  Future<void> _save() async {
    // Her veri değişimi buradan geçiyor — seri (streak) önbelleğini burada
    // temizlemek, önbelleğin bayatlamasına karşı tek ve güvenli nokta.
    _invalidateStreakCache();
    try {
      await repo.saveAll(_toMap());
    } catch (_) {
      // Kayıt başarısız (disk dolu, bulut erişilemiyor, JSON'a çevrilemeyen
      // alan...). Çoğu çağrı yeri bunu await ETMEDİĞİ için burada fırlayan
      // hata "unhandled async exception" olarak kalırdı; boot() içindeki
      // `await _save()` çağrılarında ise uygulamanın açılışını komple
      // engelleyebilirdi. Veri bellekte doğru; bir sonraki değişiklikte
      // yeniden yazılmaya çalışılır.
    }
  }

  /// Diğer tüm alanları class alan varsayılanlarına döndürür — hesap
  /// SAHİPLİĞİ değişirken (çıkış yapılırken ya da farklı/yeni bir hesaba
  /// geçilirken) önceki hesabın verisinin cihazda/hafızada kalmaması için.
  /// isPro/themeId/darkMode DA sıfırlanır: bunlar _toMap()/load() ile zaten
  /// hesap başına buluta kaydediliyor, yani fiilen hesap verisi — biri
  /// resetlenmezse yeni/farklı bir hesap bir öncekinin Pro durumunu ve
  /// temasını miras alır (bkz. onSignedIn). Gerçek satın alma bu cihazda
  /// geçerliyse onSignedIn() sonrasında Iap.restore() ile hemen geri gelir.
  void _resetAccountScopedState() {
    streaks = [];
    tasks = [];
    doneByDate = {};
    waterByDate = {};
    waterLog = {};
    weekly = [];
    events = [];
    water = WaterState(date: todayKey());
    checklistFullDays = [];
    celebrated = {};
    sharedStreakIds = {};
    myFriendCode = null;
    friendships = [];
    _sharedByFriend = {};
    userName = '';
    createdAtMs = null;
    reviewAsked = false;
    weeklyReportsSeen = 0;
    triggerLog = [];
    adaptiveDismissed = {};
    isPro = false;
    proTrialUntilMs = null;
    themeId = 'beyaz';
    darkMode = false; // 'beyaz' temanın açık paletiyle tutarlı (bkz. alan tanımı)
    currentTheme = themeById(themeId);
    useDarkPalette = darkMode;
  }

  /// Uygulama açılışında (main.dart → bootRutin) çağrılır. Kalıcı bir
  /// Supabase oturumu varsa (kullanıcı daha önce giriş yapmış ve uygulama
  /// kapatılıp açılmış) doğrudan bulut deposunu kullanır; buluta hiç veri
  /// yazılmamışsa (ör. bu hesap bu özellikten önce hep yerelde kullanılmış)
  /// cihazdaki mevcut veriyi kaybetmemek için önce yerelden yükleyip
  /// buluta TAŞIR (migration). Oturum yoksa her zamanki gibi yerel depoyu
  /// kullanır.
  Future<void> boot() async {
    // Supabase yapılandırılmış görünse bile client henüz hazır değilse
    // (initialize sessizce başarısız olduysa) `Supabase.instance` fırlatır;
    // bu, main() zincirinde uygulamanın hiç açılmamasına yol açardı.
    bool hasSession;
    try {
      hasSession = supabaseConfigured &&
          Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      hasSession = false;
    }
    if (!hasSession) {
      repo = const LocalRepository();
      await load();
      return;
    }
    const cloud = CloudRepository();
    LoadResult cloudResult;
    try {
      cloudResult = await cloud.loadAll();
    } catch (_) {
      cloudResult = const LoadResult.failure();
    }

    // Okuma BAŞARISIZ olduysa buluta hiçbir şey YAZILMAZ.
    //
    // Bu ayrım kritik: eskiden "veri gelmedi" ile "veri yok" aynı şeydi
    // (ikisi de null) ve geçici bir ağ hatası şu felakete yol açıyordu —
    // hesap yepyeni sanılır, cihazdaki (çoğu zaman boş) veri yüklenir ve
    // hemen buluta yazılarak kullanıcının GERÇEK bulut verisi kalıcı olarak
    // silinirdi. Artık okuma başarısızsa yalnızca cihazdaki kopyayla devam
    // edilir; bulut olduğu gibi korunur ve bağlantı geri geldiğinde bir
    // sonraki kayıt durumu normal şekilde senkronlar.
    if (cloudResult.failed) {
      repo = cloud;
      await load();
      return;
    }
    if (cloudResult.data != null) {
      repo = cloud;
      await load();
      return;
    }
    // Okuma başarılı ve bu hesap için gerçekten kayıt yok: yereldeki mevcut
    // veriyi yükleyip ilk kez buluta taşı (migration).
    repo = const LocalRepository();
    await load();
    repo = cloud;
    await _save();
  }

  /// Uygulama içinden başarılı bir giriş/kayıt/OAuth sonrası çağrılır
  /// (bkz. ui/auth_screen.dart). Bu hesabın bulutta kayıtlı verisi varsa
  /// onu yükler. Yoksa (yeni hesap) önce cihazda bir önceki hesaba/oturuma
  /// ait kalmış olabilecek her şey (habit, Pro durumu, tema...) sıfırlanır
  /// — böylece yeni bir hesap asla bir öncekinin Pro'sunu ya da temasını
  /// miras almaz. Ardından bu cihazın gerçek Play/App Store satın alımı
  /// varsa Iap.restore() onu bu hesap için hemen yeniden açar.
  Future<void> onSignedIn() async {
    if (!supabaseConfigured) return;
    const cloud = CloudRepository();
    LoadResult cloudResult;
    try {
      cloudResult = await cloud.loadAll();
    } catch (_) {
      cloudResult = const LoadResult.failure();
    }
    _resetAccountScopedState();
    repo = cloud;
    if (cloudResult.failed) {
      // Bulut okunamadı. Buraya `_save()` KOYULAMAZ: durum az önce
      // sıfırlandığı için bu, kullanıcının bulut verisinin üzerine BOŞ bir
      // belge yazıp hesabını kalıcı olarak boşaltmak olurdu. Veri yazmadan
      // çık; bağlantı geri geldiğinde bir sonraki açılış/kayıt senkronlar.
      notifyListeners();
      unawaited(hw.syncHomeWidget(this));
      return;
    }
    if (cloudResult.data != null) {
      await load(); // load() zaten widget'ı senkronize eder
    } else {
      await _save();
      // Yeni/boş hesap: load() çalışmadığı için widget'ı burada temizle,
      // aksi halde önceki hesabın görevleri ana ekranda asılı kalır.
      unawaited(hw.syncHomeWidget(this));
    }
    notifyListeners();
    unawaited(Iap.instance.restore());
  }

  /// Tüm verinin JSON yedeği (dışa aktarma için).
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Rutin',
      'exportedAt': DateTime.now().toIso8601String(),
      'streaks': streaks.map((e) => e.toJson()).toList(),
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'doneByDate': doneByDate,
      'waterByDate': waterByDate,
      'weekly': weekly.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'water': water.toJson(),
      'checklistFullDays': checklistFullDays,
      // Tetikleyici/nüks kayıtları da dışa aktarılır: bunlar kullanıcının
      // en hassas kişisel verisi (ne zaman, neden zorlandığı) ve GDPR veri
      // taşınabilirliği kapsamında ona ait. Dışarıda bırakmak, "verini
      // istediğin an indir" vaadini eksik bırakırdı.
      'triggerLog': triggerLog.map((e) => e.toJson()).toList(),
    });
  }

  void _scheduleEvening() {
    if (!remindersEnabled) return;
    final total = todaysTasks.length;
    // scheduleEveningSummary ASYNC'tir ama burada await EDİLMEZ (bu metod void).
    // Await edilmeyen bir Future'ın fırlattığı hata senkron try/catch'e DÜŞMEZ;
    // doğrudan PlatformDispatcher.onError'a kaçıp uygulamayı FATAL olarak
    // raporlar (gerçekte yaşandı: bazı cihazlarda bildirim ikonu kaynağı
    // çözülemeyince `invalid_icon` fırladı ve fatal düştü). `.catchError` ile
    // Future'ın hatasını burada yutuyoruz: bildirim kurulamazsa uygulama akışı
    // etkilenmemeli.
    notifications
        .scheduleEveningSummary(t(
            '✅ $doneCount/$total görev • 💧 ${water.count}/${water.goal} bardak — günü tamamla, serini koru!',
            '✅ $doneCount/$total tasks • 💧 ${water.count}/${water.goal} glasses — finish the day, keep the streak!'))
        .catchError((_) {});
  }

  void _calendarChanged() {
    if (remindersEnabled) {
      notifications.scheduleCalendarReminders(weekly, events);
    }
    _save();
    notifyListeners();
  }

  /// Gün değiştiyse su sayacını sıfırlar, 400 günden eski kayıtları temizler.
  /// Değişiklik olmadıysa diske yazmaz (sık çağrılabilir — örn. her build'de).
  void dailyRollover() {
    var changed = false;
    final t = todayKey();
    // Gün dönmüş olabilir — seriler "bugüne" göre hesaplandığı için önbellek
    // her rollover kontrolünde geçersiz kılınmalı (uygulama gece yarısını
    // açıkken geçtiğinde bayat seri göstermemesi için).
    _invalidateStreakCache();
    if (water.date != t) {
      water.date = t;
      water.count = 0;
      changed = true;
    }
    for (final m in [doneByDate, waterByDate]) {
      final keys = m.keys.toList()..sort();
      while (keys.length > 400) {
        m.remove(keys.removeAt(0));
        changed = true;
      }
    }
    final logKeys = waterLog.keys.toList()..sort();
    while (logKeys.length > 400) {
      waterLog.remove(logKeys.removeAt(0));
      changed = true;
    }
    if (changed) _save();
    unawaited(hw.syncHomeWidget(this));
  }

  // ---------- Streak ----------

  void addStreak(String name,
      {DateTime? start,
      double dailyCost = 0,
      double dailyHours = 0,
      String emoji = ''}) {
    streaks.add(Streak(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      start: start ?? DateTime.now(),
      dailyCost: dailyCost,
      dailyHours: dailyHours,
      emoji: emoji,
    ));
    _save();
    notifyListeners();
  }

  /// Var olan bir recovery/streak kaydını günceller.
  void editStreak(Streak s,
      {String? name,
      DateTime? start,
      double? dailyCost,
      double? dailyHours,
      String? emoji}) {
    if (name != null) s.name = name;
    if (start != null) s.start = start;
    if (dailyCost != null) s.dailyCost = dailyCost;
    if (dailyHours != null) s.dailyHours = dailyHours;
    if (emoji != null) s.emoji = emoji;
    _save();
    notifyListeners();
  }

  /// Kullanıcının kaç kez haftalık rapor açtığı. İlk rapor ücretsiz
  /// gösterilir (değeri anlatmak yerine yaşatmak); sonrakiler Pro
  /// (bkz. ui/weekly_report_screen.dart).
  int weeklyReportsSeen = 0;

  /// "Hedefini küçült" önerisi kullanıcı tarafından kapatılan görev id'leri.
  /// Öneri reddedildikten sonra 30 gün boyunca tekrar gösterilmez —
  /// aksi halde her açılışta aynı öneriyi görmek dırdıra dönüşür.
  Map<String, int> adaptiveDismissed = {}; // 'taskId' -> epoch ms

  /// Son 7 günde en az [minMisses] kez kaçırılmış, öneri gösterilmesi
  /// anlamlı olan ilk görevi döndürür (yoksa null).
  ///
  /// Bu özellik, kategorideki en büyük terk sebebini hedefler: insanlar
  /// alışkanlığı beceremediklerinde uygulamayı SİLERLER, çünkü uygulama
  /// her açılışta başarısızlıklarını hatırlatır. Rakipler burada ceza
  /// mekaniği (seri kırılması, kırmızı işaretler) kurar; biz uyarlanma
  /// öneriyoruz — "hedefi küçültelim mi?".
  TaskItem? adaptiveSuggestion({int minMisses = 4}) {
    final now = DateTime.now();
    for (final task in tasks) {
      final dismissedAt = adaptiveDismissed['${task.id}'];
      if (dismissedAt != null &&
          now.millisecondsSinceEpoch - dismissedAt <
              const Duration(days: 30).inMilliseconds) {
        continue;
      }
      var misses = 0;
      var active = 0;
      for (var i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: i));
        if (!task.activeOn(mondayIndex(day))) continue;
        active++;
        if (!(doneByDate[todayKey(day)] ?? const <int>[]).contains(task.id)) {
          misses++;
        }
      }
      // En az 5 aktif gün olsun ki "yeni eklenmiş alışkanlık" için
      // haksız bir öneri çıkmasın.
      if (active >= 5 && misses >= minMisses) return task;
    }
    return null;
  }

  void dismissAdaptiveSuggestion(TaskItem task) {
    adaptiveDismissed['${task.id}'] = DateTime.now().millisecondsSinceEpoch;
    _save();
    notifyListeners();
  }

  /// Kriz/nüks bağlam kaydı ekler (bkz. TriggerEntry, ui/trigger_sheet.dart).
  ///
  /// Kayıt sayısı 500 ile sınırlanır — bu veri buluta JSON olarak yazıldığı
  /// için sınırsız büyümesi hem senkronizasyonu yavaşlatır hem de depolama
  /// kotasını şişirir. En eski kayıtlar düşer; desen analizi zaten güncel
  /// veriye dayanır.
  void addTriggerEntry({
    required int streakId,
    required String trigger,
    required bool survived,
  }) {
    triggerLog.add(TriggerEntry(
      streakId: streakId,
      atMs: DateTime.now().millisecondsSinceEpoch,
      trigger: trigger,
      survived: survived,
    ));
    while (triggerLog.length > 500) {
      triggerLog.removeAt(0);
    }
    _save();
    notifyListeners();
  }

  void markWeeklyReportSeen() {
    weeklyReportsSeen++;
    _save();
    // notifyListeners ÇAĞRILMIYOR: bu, ekran ilk çizildikten hemen sonra
    // (postFrameCallback) tetikleniyor; burada dinleyicileri uyandırmak
    // aynı karede ikinci bir yeniden çizim başlatıp raporun kilit
    // durumunun gözle görülür şekilde "atlamasına" yol açardı. Sayaç bir
    // sonraki açılışta zaten güncel okunur.
  }

  /// "Geleceğe Mektup"u kaydeder (bkz. Streak.letter). Boş metin mektubu
  /// siler. Nüks (resetStreak) mektuba DOKUNMAZ — kullanıcının kendine
  /// yazdığı söz, düştüğünde silinmemeli; asıl o an lazım olur.
  void setStreakLetter(Streak s, String letter) {
    s.letter = letter.trim();
    _save();
    notifyListeners();
  }

  /// Sıfırlar; sıfırlanan seri gün sayısını döndürür. Nüksetme sayacını artırır.
  int resetStreak(Streak s) {
    final days = s.days;
    // Nüks: churn'ün en güçlü öncü sinyali. Kaçıncı nükste ve kaç gün sonra
    // olduğu, geri kazanım akışını tasarlamak için gerekli. Bırakılan şeyin
    // ADI ASLA gönderilmez — yalnızca sayılar.
    Analytics.instance.log(Ev.streakRelapse, {
      'days': days,
      'relapse_no': s.relapses + 1,
    });
    if (days > s.bestDays) s.bestDays = days;
    s.relapses++;
    s.start = DateTime.now();
    _save();
    notifyListeners();
    return days;
  }

  void deleteStreak(Streak s) {
    streaks.remove(s);
    _save();
    notifyListeners();
  }

  void restoreStreak(Streak s) {
    streaks.add(s);
    _save();
    notifyListeners();
  }

  // ---------- Checklist ----------

  List<int> get todaysDone => doneByDate.putIfAbsent(todayKey(), () => []);

  /// Bugün geçerli görevler (güne özel görevler filtrelenir).
  List<TaskItem> get todaysTasks =>
      tasks.where((t) => t.activeOn(mondayIndex(DateTime.now()))).toList();

  int get doneCount =>
      todaysDone.where((id) => todaysTasks.any((t) => t.id == id)).length;

  void addTask(String name,
      {List<int>? days, String emoji = '', String category = ''}) {
    tasks.add(TaskItem(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        days: days,
        emoji: emoji,
        category: category));
    _save();
    notifyListeners();
  }

  /// Var olan bir görevi günceller (yeni arayüz habit düzenleme).
  void editTask(TaskItem task,
      {String? name, List<int>? days, String? emoji, String? category}) {
    if (name != null) task.name = name;
    if (days != null) task.days = days;
    if (emoji != null) task.emoji = emoji;
    if (category != null) task.category = category;
    _save();
    notifyListeners();
  }

  /// Bir görevin bugünden geriye kesintisiz tamamlanma serisi (gün).
  /// Yalnızca görevin aktif olduğu günler sayılır; aktif olmayan günler
  /// seriyi bozmaz, atlanır. Bugün henüz işaretlenmediyse dünden başlar.
  /// [taskStreak] sonuç önbelleği. Bu hesap her çağrıda 2000 güne kadar
  /// geriye gidip her gün için tarih anahtarı üretebiliyor; ana ekranda hem
  /// her alışkanlık satırı hem [maxHabitStreak] hem de rozet/analitik
  /// hesapları bunu ARKA ARKAYA çağırdığı için her yeniden çizimde aynı iş
  /// onlarca kez tekrarlanıyordu. Veri her değiştiğinde
  /// ([_invalidateStreakCache], toggleTask/load/dailyRollover) temizlenir.
  final Map<int, int> _streakCache = {};

  void _invalidateStreakCache() => _streakCache.clear();

  int taskStreak(TaskItem task) {
    final cached = _streakCache[task.id];
    if (cached != null) return cached;
    final computed = _computeTaskStreak(task);
    _streakCache[task.id] = computed;
    return computed;
  }

  int _computeTaskStreak(TaskItem task) {
    var streak = 0;
    var day = DateTime.now();
    // Bugün aktif ve işaretlenmemişse seriyi dünden say (henüz gün bitmedi).
    if (task.activeOn(mondayIndex(day)) &&
        !(doneByDate[todayKey(day)] ?? const <int>[]).contains(task.id)) {
      day = day.subtract(const Duration(days: 1));
    }
    // Emniyet sınırı: en fazla 2000 gün geri bak.
    for (var i = 0; i < 2000; i++) {
      if (!task.activeOn(mondayIndex(day))) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }
      if ((doneByDate[todayKey(day)] ?? const <int>[]).contains(task.id)) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Tüm görevler arasındaki en uzun aktif seri.
  int get maxHabitStreak {
    var best = 0;
    for (final task in tasks) {
      final st = taskStreak(task);
      if (st > best) best = st;
    }
    return best;
  }

  void toggleTask(TaskItem task) {
    final done = todaysDone;
    if (done.contains(task.id)) {
      done.remove(task.id);
    } else {
      done.add(task.id);
      // Ana etkileşim olayı — D1/D7/D30 retention'ın anlamlı tanımı
      // "uygulamayı açtı" değil, "gerçekten kullandı"dır.
      Analytics.instance.log(Ev.habitCheck, {'streak': taskStreak(task)});
      final today = todaysTasks;
      if (today.isNotEmpty && doneCount == today.length && pushNotifications) {
        notifications.showNow(t('🎉 Tebrikler!', '🎉 Congrats!'),
            t('Bugünün tüm görevlerini tamamladın.', 'You completed all of today\'s tasks.'));
      }
    }
    // Checklist streak kaydı: gün tamamen bittiyse işaretle, bozulduysa kaldır.
    final t0 = todayKey();
    final full = todaysTasks.isNotEmpty && doneCount == todaysTasks.length;
    if (full && !checklistFullDays.contains(t0)) {
      checklistFullDays.add(t0);
    } else if (!full) {
      checklistFullDays.remove(t0);
    }
    _scheduleEvening();
    _save();
    unawaited(hw.syncHomeWidget(this));
    notifyListeners();
  }

  /// Üst üste kaç gün listenin tamamı bitirildi (bugün dahil,
  /// bugün henüz bitmediyse dünden geriye sayar).
  int get checklistStreak {
    var streak = 0;
    var day = DateTime.now();
    if (!checklistFullDays.contains(todayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (checklistFullDays.contains(todayKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ---------- Kutlama ----------

  /// Kutlanmamış bir milestone'a ulaşan ilk streak'i döndürür.
  ({Streak streak, int milestone})? get pendingCelebration {
    for (final s in streaks) {
      final reached =
          milestones.where((m) => s.days >= m).fold(0, (a, b) => b > a ? b : a);
      if (reached > 0 && (celebrated['${s.id}'] ?? 0) < reached) {
        return (streak: s, milestone: reached);
      }
    }
    return null;
  }

  void markCelebrated(Streak s, int milestone) {
    celebrated['${s.id}'] = milestone;
    _save();
    notifyListeners();
  }

  // ---------- Onboarding ----------

  void finishOnboarding(
      {String? streakName,
      List<String> sampleTasks = const [],
      String? name}) {
    createdAtMs ??= DateTime.now().millisecondsSinceEpoch;
    if (name != null && name.trim().isNotEmpty) userName = name.trim();
    if (streakName != null && streakName.trim().isNotEmpty) {
      streaks.add(Streak(
          id: DateTime.now().millisecondsSinceEpoch,
          name: streakName.trim(),
          start: DateTime.now()));
    }
    for (final name in sampleTasks) {
      tasks.add(TaskItem(
          id: DateTime.now().millisecondsSinceEpoch + tasks.length, name: name));
    }
    onboarded = true;
    // Huninin en kritik dönüm noktası: kullanıcı kuruluma kadar geldi.
    // Kaç alışkanlıkla başladığı, ilerideki retention'ın en güçlü
    // yordayıcılarından biridir (SAYI gönderilir, isim ASLA).
    Analytics.instance.log(Ev.onboardingComplete, {
      'streaks': streaks.length,
      'tasks': tasks.length,
    });
    _save();
    notifyListeners();
    // Bildirim izni TAM BURADA isteniyor: kullanıcı artık ne takip edeceğini
    // seçmiş durumda, dolayısıyla "sana bunu hatırlatalım mı?" sorusunun bir
    // karşılığı var. Açılışta bağlamsız sorulduğunda ret oranı çok daha
    // yüksekti (bkz. main.dart'taki açıklama). İzin verilirse hatırlatıcılar
    // hemen kurulur.
    unawaited(_requestNotificationsAfterOnboarding());
  }

  Future<void> _requestNotificationsAfterOnboarding() async {
    try {
      await notifications.requestPermission();
      await applyNotificationSettings();
    } catch (_) {
      // İzin alınamadı ya da zamanlama kurulamadı; uygulama normal çalışır.
    }
  }

  void deleteTask(TaskItem t) {
    tasks.remove(t);
    _save();
    notifyListeners();
  }

  void restoreTask(TaskItem t) {
    tasks.add(t);
    _save();
    notifyListeners();
  }

  // ---------- Su ----------
  //
  // ÖNEMLİ: `water.count` ("bardak" sayacı) artık asla elle artırıp
  // azaltılmıyor. Eskiden her ekleme/kaldırmada ml'yi 250'ye bölüp
  // yuvarlayarak (en az 1 bardak) sayaca +/- ekleniyordu — bu, art arda
  // küçük miktarlar eklenip kaldırıldığında gerçek toplam ml'den sapan
  // (genelde şişen) bir sayaç üretiyordu; "iptal et" bir eklemeyi tam
  // olarak geri almıyordu. Artık sayaç HER zaman [todaysWaterLog]'daki
  // gerçek ml toplamından yeniden HESAPLANIYOR (_recomputeWaterFromLog),
  // bu yüzden ekleme/kaldırma birbirinin birebir tersi — sapma imkansız.

  /// Bugünün su kayıt defteri (en yeni önce).
  List<WaterLogEntry> get todaysWaterLog =>
      waterLog.putIfAbsent(todayKey(), () => []);

  /// Bugün gerçekten içilen toplam su (ml) — kayıt defterinden toplanır.
  int get todaysWaterMl =>
      todaysWaterLog.fold<int>(0, (a, e) => a + e.ml);

  /// [todaysWaterLog]'daki gerçek ml toplamından bardak sayacını yeniden
  /// hesaplar (elle +/- değil, her zaman SET eder). Hedefe yeni ulaşıldıysa
  /// bildirim gösterir.
  void _recomputeWaterFromLog() {
    final prevCount = water.count;
    final newCount = (todaysWaterMl / 250).round().clamp(0, 99);
    water.count = newCount;
    waterByDate[todayKey()] = newCount;
    if (newCount > prevCount &&
        newCount >= water.goal &&
        prevCount < water.goal &&
        pushNotifications) {
      notifications.showNow(t('💧 Hedef tamam!', '💧 Goal reached!'),
          t('Bugünkü su hedefine ulaştın. Süpersin!', 'You hit today\'s water goal. Awesome!'));
    }
    _scheduleEvening();
    _save();
    notifyListeners();
  }

  /// Belirli ml miktarında su ekler: gerçek miktar kayıt defterine işlenir,
  /// bardak sayacı deftere göre yeniden hesaplanır.
  void addWaterMl(int ml) {
    if (ml <= 0) return;
    dailyRollover();
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    todaysWaterLog.insert(0, WaterLogEntry(ml: ml, time: time));
    _recomputeWaterFromLog();
  }

  /// Bir su kaydını geri alır (kayıt defterinden çıkarır, sayaç deftere
  /// göre yeniden hesaplanır — eklemenin birebir tersi).
  void removeWaterLog(WaterLogEntry e) {
    if (todaysWaterLog.remove(e)) {
      _recomputeWaterFromLog();
    }
  }

  Future<void> setWaterInterval(int minutes) async {
    water.intervalMinutes = minutes;
    // Hatırlatıcılar kapalıysa hiçbir şey zamanlama (0 = iptal).
    await notifications.scheduleWaterReminders(remindersEnabled ? minutes : 0);
    _save();
    notifyListeners();
  }

  /// Günlük su hedefini [delta] bardak artırır/azaltır (1–20 arası).
  /// Yeni arayüzdeki +/- hedef butonları buradan geçer.
  void changeGoal(int delta) {
    water.goal = (water.goal + delta).clamp(1, 20);
    _save();
    notifyListeners();
  }

  // ---------- Takvim ----------

  void addWeekly(int day, String time, String name) {
    weekly.add(WeeklyItem(
        id: DateTime.now().millisecondsSinceEpoch, day: day, time: time, name: name));
    _calendarChanged();
  }

  void deleteWeekly(WeeklyItem w) {
    weekly.remove(w);
    _calendarChanged();
  }

  void restoreWeekly(WeeklyItem w) {
    weekly.add(w);
    _calendarChanged();
  }

  void addEvent(String date, String time, String name) {
    events.add(EventItem(
        id: DateTime.now().millisecondsSinceEpoch, date: date, time: time, name: name));
    _calendarChanged();
  }

  void deleteEvent(EventItem e) {
    events.remove(e);
    _calendarChanged();
  }

  void restoreEvent(EventItem e) {
    events.add(e);
    _calendarChanged();
  }

  /// Bugünün programı: bugünkü randevular + bugüne denk gelen haftalık ögeler.
  List<({String time, String name, bool recurring})> todaysPlan() {
    final dow = mondayIndex(DateTime.now());
    final t = todayKey();
    final items = <({String time, String name, bool recurring})>[
      ...events
          .where((e) => e.date == t)
          .map((e) => (time: e.time, name: e.name, recurring: false)),
      ...weekly
          .where((w) => w.day == dow)
          .map((w) => (time: w.time, name: w.name, recurring: true)),
    ];
    items.sort((a, b) =>
        (a.time.isEmpty ? '99:99' : a.time).compareTo(b.time.isEmpty ? '99:99' : b.time));
    return items;
  }

  // ---------- İstatistik ----------

  /// Son [n] gün için (tarih, tamamlanan görev sayısı) listesi — en eski önce.
  List<({String key, DateTime day, int done})> taskHistory(int n) {
    return List.generate(n, (i) {
      final day = DateTime.now().subtract(Duration(days: n - 1 - i));
      final key = todayKey(day);
      return (key: key, day: day, done: (doneByDate[key] ?? []).length);
    });
  }

  /// Son [n] gün için (tarih, bardak) listesi — en eski önce.
  List<({String key, DateTime day, int count})> waterHistory(int n) {
    return List.generate(n, (i) {
      final day = DateTime.now().subtract(Duration(days: n - 1 - i));
      final key = todayKey(day);
      return (key: key, day: day, count: waterByDate[key] ?? 0);
    });
  }

  // ---------- Profil / Ayarlar / Hesap ----------

  void setUserName(String name) {
    userName = name.trim();
    _save();
    notifyListeners();
  }

  /// Manuel dil seçimi. null = cihaz diline geri dön.
  void setLanguage(String? code) {
    localeOverride = code;
    if (code != null) {
      T.en = code == 'en';
    } else {
      T.init();
    }
    _save();
    notifyListeners();
  }

  /// Yeni arayüz ayar toggle'larını kaydeder.
  void setSettings({
    bool? push,
    bool? daily,
    bool? sounds,
    bool? haptics,
    bool? weekStartsMonday,
  }) {
    if (push != null) pushNotifications = push;
    if (daily != null) dailyReminders = daily;
    if (sounds != null) this.sounds = sounds;
    if (haptics != null) this.haptics = haptics;
    if (weekStartsMonday != null) this.weekStartsMonday = weekStartsMonday;
    _save();
    notifyListeners();
    // Bildirim toggle'ları değiştiyse gerçek zamanlamayı hemen uygula:
    // açıldıysa yeniden kur, kapatıldıysa tüm hatırlatıcıları iptal et.
    if (push != null || daily != null) {
      applyNotificationSettings();
    }
  }

  /// "Member since" için formatlanabilir tarih.
  DateTime? get memberSince =>
      createdAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAtMs!);

  /// Uygulamayı ilk kez açtığı günden bu yana geçen aktif gün sayısı.
  int get daysActive {
    if (createdAtMs == null) return 0;
    final start = DateTime.fromMillisecondsSinceEpoch(createdAtMs!);
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return b.difference(a).inDays + 1;
  }

  /// Çıkış: bulut oturumunu kapatır (yapılandırılmışsa), onboarding'e
  /// döner, yerel veriyi silmez.
  /// Bulut oturumunu kapatır ve bu hesaba ait veriyi cihazdan temizler.
  /// Veri zaten bulutta (bkz. onSignedIn/_save) yedekli olduğu için
  /// kaybolmaz — aynı hesaba tekrar giriş yapıldığında [onSignedIn] onu
  /// geri yükler. Bu temizlik, farklı bir hesapla giriş yapıldığında bir
  /// önceki hesabın verisinin cihazda görünmeye devam etmesini
  /// (hesap-değiştirme sızıntısı) engeller.
  Future<void> signOut() async {
    await authService.signOut();
    _resetAccountScopedState();
    repo = const LocalRepository();
    onboarded = false;
    await _save();
    // Ana ekran widget'ı ayrı bir depoda (SharedPreferences/App Group)
    // yaşıyor; temizlenmezse çıkış yapan kullanıcının alışkanlık isimleri
    // telefonun ana ekranında görünmeye devam ederdi.
    unawaited(hw.syncHomeWidget(this));
    notifyListeners();
  }

  /// Hesabı ve tüm veriyi (yerel + bulut) tamamen siler. Supabase
  /// yapılandırılmışsa önce sunucudaki hesabı da siler (Play/App Store
  /// zorunluluğu) — `app_data` satırı da `on delete cascade` ile otomatik
  /// silinir; bu çağrı başarısız olsa bile yerel temizlik yine de
  /// tamamlanır.
  /// Sunucudaki hesap da gerçekten silinebildiyse `true` döner. `false`
  /// dönerse cihaz temizlenmiştir ama bulut hesabı durmaktadır ve arayüz
  /// bunu kullanıcıya SÖYLEMEK zorundadır (bkz. settings_screen.dart).
  Future<bool> wipeAllData() async {
    final serverDeleted = await authService.deleteAccount();
    _resetAccountScopedState();
    repo = const LocalRepository();
    isPro = false;
    onboarded = false;
    await _save();
    await notifications.cancelAllReminders();
    // Hesap silindi — widget'taki kalıntı veriyi de temizle (bkz. signOut).
    unawaited(hw.syncHomeWidget(this));
    notifyListeners();
    return serverDeleted;
  }
}