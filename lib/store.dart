/// Uygulama durumu (state) ve iş mantığı.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

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
  final Repository repo;
  final NotificationService notifications;

  List<Streak> streaks = [];
  List<TaskItem> tasks = [];
  Map<String, List<int>> doneByDate = {}; // 'yyyy-MM-dd' -> [taskId]
  Map<String, int> waterByDate = {}; // 'yyyy-MM-dd' -> bardak
  List<WeeklyItem> weekly = [];
  List<EventItem> events = [];
  WaterState water = WaterState(date: todayKey());

  // Pro / tema
  String themeId = 'alev';
  bool isPro = false;

  // Kullanıcı profili (yeni arayüz)
  String userName = '';
  int? createdAtMs; // hesabın oluşturulma zamanı ("Member since")

  // Su kayıt defteri: 'yyyy-MM-dd' -> [ {ml, time} ]
  Map<String, List<WaterLogEntry>> waterLog = {};

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
  }

  /// Ücretsiz sürümde en fazla bu kadar streak açılabilir.
  static const freeStreakLimit = 2;

  bool get canAddStreak => isPro || streaks.length < freeStreakLimit;

  AppState({required this.repo, required this.notifications});

  void setTheme(String id) {
    themeId = id;
    currentTheme = themeById(id);
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

  Future<void> load() async {
    final data = await repo.loadAll();
    if (data != null) {
      streaks = ((data['streaks'] ?? []) as List)
          .map((e) => Streak.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      tasks = ((data['tasks'] ?? []) as List)
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      doneByDate = ((data['doneByDate'] ?? {}) as Map).map(
          (k, v) => MapEntry(k as String, (v as List).map((e) => e as int).toList()));
      waterByDate = ((data['waterByDate'] ?? {}) as Map)
          .map((k, v) => MapEntry(k as String, v as int));
      weekly = ((data['weekly'] ?? []) as List)
          .map((e) => WeeklyItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      events = ((data['events'] ?? []) as List)
          .map((e) => EventItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (data['water'] != null) {
        water = WaterState.fromJson(Map<String, dynamic>.from(data['water']));
      }
      themeId = (data['themeId'] ?? 'alev') as String;
      isPro = (data['isPro'] ?? false) as bool;
      userName = (data['userName'] ?? '') as String;
      createdAtMs = data['createdAtMs'] as int?;
      waterLog = ((data['waterLog'] ?? {}) as Map).map((k, v) => MapEntry(
          k as String,
          (v as List)
              .map((e) => WaterLogEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()));
      pushNotifications = (data['pushNotifications'] ?? true) as bool;
      dailyReminders = (data['dailyReminders'] ?? true) as bool;
      sounds = (data['sounds'] ?? false) as bool;
      haptics = (data['haptics'] ?? true) as bool;
      weekStartsMonday = (data['weekStartsMonday'] ?? true) as bool;
      localeOverride = data['localeOverride'] as String?;
      onboarded = (data['onboarded'] ?? false) as bool;
      checklistFullDays = ((data['checklistFullDays'] ?? []) as List)
          .map((e) => e as String)
          .toList();
      celebrated = ((data['celebrated'] ?? {}) as Map)
          .map((k, v) => MapEntry(k as String, v as int));
      sharedStreakIds = ((data['sharedStreakIds'] ?? []) as List)
          .map((e) => e as int)
          .toSet();
      reviewAsked = (data['reviewAsked'] ?? false) as bool;
    }
    if (localeOverride != null) T.en = localeOverride == 'en';
    currentTheme = themeById(themeId);
    dailyRollover();
    await applyNotificationSettings();
    notifyListeners();
  }

  /// Bildirim ayarlarının (push + günlük hatırlatma) izin verdiği durumda
  /// su, takvim ve akşam özeti hatırlatıcılarını (yeniden) kurar; aksi halde
  /// hepsini iptal eder. Zamanlanan tüm hatırlatıcılar tek noktadan geçer.
  bool get remindersEnabled => pushNotifications && dailyReminders;

  Future<void> applyNotificationSettings() async {
    if (remindersEnabled) {
      await notifications.scheduleWaterReminders(water.intervalMinutes);
      await notifications.scheduleCalendarReminders(weekly, events);
      _scheduleEvening();
    } else {
      await notifications.cancelAllReminders();
    }
  }

  Future<void> _save() async {
    await repo.saveAll({
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
    });
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
    });
  }

  void _scheduleEvening() {
    if (!remindersEnabled) return;
    final total = todaysTasks.length;
    notifications.scheduleEveningSummary(t(
        '✅ $doneCount/$total görev • 💧 ${water.count}/${water.goal} bardak — günü tamamla, serini koru!',
        '✅ $doneCount/$total tasks • 💧 ${water.count}/${water.goal} glasses — finish the day, keep the streak!'));
  }

  void _calendarChanged() {
    if (remindersEnabled) {
      notifications.scheduleCalendarReminders(weekly, events);
    }
    _save();
    notifyListeners();
  }

  /// Gün değiştiyse su sayacını sıfırlar, 60 günden eski kayıtları temizler.
  void dailyRollover() {
    final t = todayKey();
    if (water.date != t) {
      water.date = t;
      water.count = 0;
    }
    for (final m in [doneByDate, waterByDate]) {
      final keys = m.keys.toList()..sort();
      while (keys.length > 60) {
        m.remove(keys.removeAt(0));
      }
    }
    final logKeys = waterLog.keys.toList()..sort();
    while (logKeys.length > 60) {
      waterLog.remove(logKeys.removeAt(0));
    }
    _save();
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

  /// Sıfırlar; sıfırlanan seri gün sayısını döndürür. Nüksetme sayacını artırır.
  int resetStreak(Streak s) {
    final days = s.days;
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
  int taskStreak(TaskItem task) {
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
    _save();
    notifyListeners();
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

  void addWater(int n) {
    dailyRollover();
    water.count = (water.count + n).clamp(0, 99);
    waterByDate[todayKey()] = water.count;
    if (n > 0 && water.count == water.goal && pushNotifications) {
      notifications.showNow(t('💧 Hedef tamam!', '💧 Goal reached!'),
          t('Bugünkü su hedefine ulaştın. Süpersin!', 'You hit today\'s water goal. Awesome!'));
    }
    _scheduleEvening();
    _save();
    notifyListeners();
  }

  /// Bugünün su kayıt defteri (en yeni önce).
  List<WaterLogEntry> get todaysWaterLog =>
      waterLog.putIfAbsent(todayKey(), () => []);

  /// Belirli ml miktarında su ekler: bardak sayacını (250 ml/bardak, en az 1)
  /// artırır ve kayıt defterine tam ml değerini işler. Yeni arayüz için.
  void addWaterMl(int ml) {
    if (ml <= 0) return;
    dailyRollover();
    final glasses = (ml / 250).round().clamp(1, 99);
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    todaysWaterLog.insert(0, WaterLogEntry(ml: ml, time: time));
    addWater(glasses); // sayaç + hedef bildirimi + kaydet + notify
  }

  /// Bir su kaydını geri alır (sayaç ve defterden düşer).
  void removeWaterLog(WaterLogEntry e) {
    final log = todaysWaterLog;
    if (log.remove(e)) {
      final glasses = (e.ml / 250).round().clamp(1, 99);
      addWater(-glasses);
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

  /// Çıkış: onboarding'e döner, veriyi silmez.
  Future<void> signOut() async {
    onboarded = false;
    await _save();
    notifyListeners();
  }

  /// Hesabı ve tüm yerel veriyi tamamen siler.
  Future<void> wipeAllData() async {
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
    isPro = false;
    onboarded = false;
    userName = '';
    createdAtMs = null;
    reviewAsked = false;
    await _save();
    await notifications.cancelAllReminders();
    notifyListeners();
  }
}
