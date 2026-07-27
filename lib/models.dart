/// Veri modelleri.
///
/// Tüm modeller JSON'a çevrilebilir — bu sayede bugün cihazda
/// (shared_preferences), yarın bulutta (Firebase/Supabase) aynı
/// modellerle çalışılır. Sosyal katman için hazır.
library;

class Streak {
  final int id;
  String name;
  DateTime start;
  int bestDays;

  /// Bu alışkanlığın günlük maliyeti (₺). 0 = takip edilmiyor.
  double dailyCost;

  /// Bu alışkanlığın günde çaldığı süre (saat). 0 = takip edilmiyor.
  /// Yeni arayüzdeki "time reclaimed / saved" göstergesi için.
  double dailyHours;

  /// Görsel avatar emojisi (yeni arayüz recovery kartları). Boş = presetten türet.
  String emoji;

  /// Kaç kez sıfırlandı (nüksetme sayısı). Yeni arayüzde rozet/istatistik için.
  int relapses;

  /// "Geleceğe Mektup" — kullanıcının en kararlı anında (genelde bırakma
  /// gününde) kendine yazdığı, NEDEN bıraktığını anlatan mesaj.
  ///
  /// Kriz anında kullanıcıya kendi sözleriyle geri gösterilir (bkz.
  /// crisis_screen.dart). Bu, dışarıdan gelen hiçbir motivasyon sözünün
  /// yapamayacağı bir şeyi yapar: kişiyi kendi kararıyla yüzleştirir.
  /// Boş = kullanıcı henüz mektup yazmamış.
  String letter;

  Streak({
    required this.id,
    required this.name,
    required this.start,
    this.bestDays = 0,
    this.dailyCost = 0,
    this.dailyHours = 0,
    this.emoji = '',
    this.relapses = 0,
    this.letter = '',
  });

  /// Takvim günü bazlı hesap: gece yarısı geçince gün +1 olur
  /// (kullanıcı beklentisiyle uyumlu).
  int get days {
    final now = DateTime.now();
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  /// Aktif seri ile en iyi serinin büyüğü.
  int get daysOrBest => days > bestDays ? days : bestDays;

  /// Bırakıldığından beri cepte kalan para (₺).
  double get moneySaved =>
      DateTime.now().difference(start).inMinutes / 1440.0 * dailyCost;

  /// Bırakıldığından beri geri kazanılan süre (saat).
  double get hoursSaved =>
      DateTime.now().difference(start).inMinutes / 1440.0 * dailyHours;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startMs': start.millisecondsSinceEpoch,
        'bestDays': bestDays,
        'dailyCost': dailyCost,
        'dailyHours': dailyHours,
        'emoji': emoji,
        'relapses': relapses,
        'letter': letter,
      };

  factory Streak.fromJson(Map<String, dynamic> j) => Streak(
        id: j['id'] as int,
        name: j['name'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(j['startMs'] as int),
        bestDays: (j['bestDays'] ?? 0) as int,
        dailyCost: ((j['dailyCost'] ?? 0) as num).toDouble(),
        dailyHours: ((j['dailyHours'] ?? 0) as num).toDouble(),
        emoji: (j['emoji'] ?? '') as String,
        relapses: (j['relapses'] ?? 0) as int,
        letter: (j['letter'] ?? '') as String,
      );
}

class TaskItem {
  final int id;
  String name;

  /// Görevin geçerli olduğu günler (0 = Pazartesi ... 6 = Pazar).
  /// Boş liste = her gün.
  List<int> days;

  /// Görsel avatar emojisi (yeni arayüz habit kartları). Boş = varsayılan.
  String emoji;

  /// İsteğe bağlı kategori etiketi (Mindfulness, Fitness…). Boş = yok.
  String category;

  TaskItem({
    required this.id,
    required this.name,
    List<int>? days,
    this.emoji = '',
    this.category = '',
  }) : days = days ?? [];

  bool activeOn(int mondayIndex) => days.isEmpty || days.contains(mondayIndex);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'days': days, 'emoji': emoji, 'category': category};

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as int,
        name: j['name'] as String,
        days: ((j['days'] ?? []) as List).map((e) => e as int).toList(),
        emoji: (j['emoji'] ?? '') as String,
        category: (j['category'] ?? '') as String,
      );
}

/// Haftalık tekrar eden program ögesi (okul, tenis, yüzme...).
class WeeklyItem {
  final int id;
  int day; // 0 = Pazartesi ... 6 = Pazar
  String time; // 'HH:mm' veya ''
  String name;

  WeeklyItem({required this.id, required this.day, required this.time, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'day': day, 'time': time, 'name': name};

  factory WeeklyItem.fromJson(Map<String, dynamic> j) => WeeklyItem(
        id: j['id'] as int,
        day: j['day'] as int,
        time: (j['time'] ?? '') as String,
        name: j['name'] as String,
      );
}

/// Tek seferlik takvim kaydı (diş randevusu, toplantı...).
class EventItem {
  final int id;
  String date; // 'yyyy-MM-dd'
  String time; // 'HH:mm' veya ''
  String name;

  EventItem({required this.id, required this.date, required this.time, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'time': time, 'name': name};

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: j['id'] as int,
        date: j['date'] as String,
        time: (j['time'] ?? '') as String,
        name: j['name'] as String,
      );
}

/// Tek bir su kaydı — yeni arayüzdeki "Today's Log" listesi için.
/// Miktar (ml) ve saat ('HH:mm') tutulur; güne göre gruplanır.
class WaterLogEntry {
  final int ml;
  final String time; // 'HH:mm'

  WaterLogEntry({required this.ml, required this.time});

  Map<String, dynamic> toJson() => {'ml': ml, 'time': time};

  factory WaterLogEntry.fromJson(Map<String, dynamic> j) => WaterLogEntry(
        ml: (j['ml'] ?? 0) as int,
        time: (j['time'] ?? '') as String,
      );
}

/// Bir kriz/nüks anında toplanan TEK DOKUNUŞLUK bağlam kaydı.
///
/// Neden var: Kullanıcının "ne zaman ve neden zorlandığı" verisi olmadan
/// kişisel risk tahmini ve tetikleyici analizi yapılamaz. Bu kayıtlar
/// birikmeden Faz 3 özellikleri (Risk Penceresi, Tetikleyici Haritası)
/// boş çalışır — bu yüzden veri toplama BUGÜN başlamalıdır.
///
/// Toplama kuralları (bkz. ui/trigger_sheet.dart):
///  • Tek dokunuş, en fazla bir soru. Asla zorunlu değil, her zaman
///    atlanabilir.
///  • Kriz ANINDA sorulmaz — kriz atlatıldıktan ya da nüks kaydedildikten
///    SONRA sorulur. İnsanın en zor anında anket doldurtmak zalimliktir.
class TriggerEntry {
  /// Hangi bırakma kaydıyla ilgili.
  final int streakId;

  /// Olay zamanı (epoch ms). Saat/gün deseni analizinin temeli budur.
  final int atMs;

  /// Tetikleyici anahtarı: 'stress' | 'boredom' | 'social' | 'tired' |
  /// 'anger' | 'habit' | 'celebration' | 'other'
  final String trigger;

  /// Sonuç: true = atlatıldı, false = nüksetti.
  /// Hangi tetikleyicide dayanabildiğini/düştüğünü ayırt etmeyi sağlar.
  final bool survived;

  const TriggerEntry({
    required this.streakId,
    required this.atMs,
    required this.trigger,
    required this.survived,
  });

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, dynamic> toJson() => {
        'streakId': streakId,
        'atMs': atMs,
        'trigger': trigger,
        'survived': survived,
      };

  factory TriggerEntry.fromJson(Map<String, dynamic> j) => TriggerEntry(
        streakId: (j['streakId'] ?? 0) as int,
        atMs: (j['atMs'] ?? 0) as int,
        trigger: (j['trigger'] ?? 'other') as String,
        survived: (j['survived'] ?? true) as bool,
      );
}

class WaterState {
  String date; // 'yyyy-MM-dd'
  int count;
  int goal;
  int intervalMinutes; // 0 = kapalı

  WaterState({required this.date, this.count = 0, this.goal = 8, this.intervalMinutes = 0});

  Map<String, dynamic> toJson() =>
      {'date': date, 'count': count, 'goal': goal, 'interval': intervalMinutes};

  factory WaterState.fromJson(Map<String, dynamic> j) => WaterState(
        date: j['date'] as String,
        count: (j['count'] ?? 0) as int,
        goal: (j['goal'] ?? 8) as int,
        intervalMinutes: (j['interval'] ?? 0) as int,
      );
}
