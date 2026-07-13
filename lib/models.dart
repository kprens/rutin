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

  Streak({
    required this.id,
    required this.name,
    required this.start,
    this.bestDays = 0,
    this.dailyCost = 0,
    this.dailyHours = 0,
    this.emoji = '',
    this.relapses = 0,
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
