/// Haftalık Hayat Raporu — son 7 günün özeti ve gelecek hafta için tek
/// bir odak önerisi.
///
/// Neden var: Aboneliğin en güçlü tutundurma (retention) mekanizması,
/// düzenli aralıklarla teslim edilen ÖNGÖRÜLEBİLİR bir değerdir. "Pazar
/// sabahı raporumu kaçırırım" hissi, iptal kararını en çok geciktiren
/// şeydir. Ayrıca kullanıcı verisini ham grafik yerine YORUMLANMIŞ olarak
/// sunar — satılan şey grafik değil, grafiğin anlamıdır.
///
/// Tamamen yereldir: ağ isteği, AI ve çalışma zamanı maliyeti YOKTUR.
library;

import 'l10n.dart';
import 'store.dart';

/// Tek bir haftalık rapor.
class WeeklyReport {
  /// Raporun kapsadığı aralık (7 gün, bugün dahil).
  final DateTime from;
  final DateTime to;

  /// Alışkanlık tamamlama oranı (0–100).
  final int completionRate;

  /// Bu hafta tamamlanan toplam alışkanlık sayısı.
  final int doneCount;

  /// Tamamlanması mümkün olan toplam (aktif gün × alışkanlık).
  final int possibleCount;

  /// Haftanın en verimli günü (tamamlama sayısına göre). Veri yoksa null.
  final DateTime? bestDay;

  /// Haftanın en zorlandığı günü. Veri yoksa null.
  final DateTime? hardestDay;

  /// Bu hafta tüm listenin bitirildiği gün sayısı.
  final int perfectDays;

  /// Aktif bırakma takiplerinin toplam temiz gün sayısı (bu hafta içinde).
  final int cleanDays;

  /// Bu hafta cepte kalan tahmini para.
  final double moneySaved;

  /// Bu hafta geri kazanılan tahmini süre (saat).
  final double hoursSaved;

  /// Bu hafta ulaşılan yeni seri kilometre taşları (streak adı → gün).
  final List<({String name, int days})> milestones;

  /// Günlük ortalama su (bardak).
  final double avgWaterCups;

  /// Gelecek hafta için önerilen tek odak (varsa).
  final String? focusSuggestion;

  const WeeklyReport({
    required this.from,
    required this.to,
    required this.completionRate,
    required this.doneCount,
    required this.possibleCount,
    required this.bestDay,
    required this.hardestDay,
    required this.perfectDays,
    required this.cleanDays,
    required this.moneySaved,
    required this.hoursSaved,
    required this.milestones,
    required this.avgWaterCups,
    required this.focusSuggestion,
  });

  /// Rapor gösterilmeye değer mi (hiç veri yoksa boş rapor göstermeyelim).
  bool get hasData => possibleCount > 0 || cleanDays > 0 || avgWaterCups > 0;

  /// Haftanın tek cümlelik "manşeti" — kullanıcının ilk gördüğü şey.
  /// Rakam yığını değil, bir yorum olmalı.
  String get headline {
    if (cleanDays > 0 && completionRate >= 70) {
      return t('Güçlü bir hafta geçirdin.', 'You had a strong week.');
    }
    if (completionRate >= 80) {
      return t('Bu hafta neredeyse kusursuzdun.',
          'You were nearly flawless this week.');
    }
    if (completionRate >= 50) {
      return t('İstikrarlı bir hafta.', 'A steady week.');
    }
    if (cleanDays > 0) {
      return t('Alışkanlıklar zorladı ama serini korudun.',
          'Habits were hard this week — but you kept your streak.');
    }
    return t('Zor bir haftaydı. Önemli olan devam etmen.',
        'This was a tough week. What matters is that you\'re still here.');
  }
}

int _mondayIdx(DateTime d) => (d.weekday - 1) % 7;

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Son 7 günün raporunu hesaplar.
WeeklyReport buildWeeklyReport(AppState s, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = List.generate(
      7, (i) => today.subtract(Duration(days: 6 - i)));

  var doneTotal = 0;
  var possibleTotal = 0;
  var perfectDays = 0;
  DateTime? bestDay;
  DateTime? hardestDay;
  var bestCount = -1;
  var worstRate = 2.0; // 0..1; 2 = henüz atanmadı

  // Alışkanlık bazında kaçırılma sayısı (odak önerisi için).
  final missedByTask = <int, int>{};

  for (final day in days) {
    final ids = s.doneByDate[_key(day)] ?? const <int>[];
    final active =
        s.tasks.where((t0) => t0.activeOn(_mondayIdx(day))).toList();
    final done = active.where((t0) => ids.contains(t0.id)).length;

    doneTotal += done;
    possibleTotal += active.length;

    for (final t0 in active) {
      if (!ids.contains(t0.id)) {
        missedByTask[t0.id] = (missedByTask[t0.id] ?? 0) + 1;
      }
    }

    if (active.isNotEmpty && done == active.length) perfectDays++;

    if (done > bestCount) {
      bestCount = done;
      bestDay = day;
    }
    if (active.isNotEmpty) {
      final rate = done / active.length;
      if (rate < worstRate) {
        worstRate = rate;
        hardestDay = day;
      }
    }
  }

  // Hiç aktif alışkanlık yoksa "en iyi/en zor gün" anlamsız.
  if (possibleTotal == 0) {
    bestDay = null;
    hardestDay = null;
  }

  final completionRate =
      possibleTotal == 0 ? 0 : (doneTotal / possibleTotal * 100).round();

  // ---- Bırakma takipleri ----
  var cleanDays = 0;
  var moneySaved = 0.0;
  var hoursSaved = 0.0;
  final milestones = <({String name, int days})>[];

  for (final st in s.streaks) {
    // Bu hafta içinde kaç gün temiz geçirildi (seri bu haftadan önce
    // başladıysa 7, bu hafta başladıysa başlangıçtan bugüne).
    final startedThisWeek = st.start.isAfter(days.first);
    final daysThisWeek = startedThisWeek
        ? DateTime(today.year, today.month, today.day)
            .difference(DateTime(st.start.year, st.start.month, st.start.day))
            .inDays
        : 7;
    final capped = daysThisWeek.clamp(0, 7);
    cleanDays += capped;
    moneySaved += st.dailyCost * capped;
    hoursSaved += st.dailyHours * capped;

    // Bu hafta içinde geçilen kilometre taşı var mı?
    const targets = [1, 3, 7, 14, 30, 60, 90, 180, 365];
    final daysNow = st.days;
    final daysWeekAgo = daysNow - 7;
    for (final target in targets) {
      if (daysNow >= target && daysWeekAgo < target) {
        milestones.add((name: st.name, days: target));
      }
    }
  }

  // ---- Su ----
  var waterTotal = 0;
  for (final day in days) {
    waterTotal += s.waterByDate[_key(day)] ?? 0;
  }
  final avgWater = waterTotal / 7.0;

  // ---- Odak önerisi ----
  String? focus;
  if (missedByTask.isNotEmpty) {
    final worstId = missedByTask.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final matches = s.tasks.where((t0) => t0.id == worstId);
    if (matches.isNotEmpty) {
      final task = matches.first;
      final missed = missedByTask[worstId]!;
      if (missed >= 3) {
        // Sık kaçırılan alışkanlık: suçlayıcı değil, uyarlayıcı öneri.
        focus = t(
            '"${task.name}" bu hafta $missed gün kaçtı. Hedefi küçültmeyi dene — küçük ama tuttuğun bir hedef, büyük ama tutmadığından iyidir.',
            '"${task.name}" slipped $missed days this week. Try making it smaller — a small habit you keep beats a big one you don\'t.');
      } else if (missed > 0) {
        focus = t(
            'Gelecek hafta tek bir şeye odaklan: "${task.name}".',
            'Focus on one thing next week: "${task.name}".');
      }
    }
  }
  if (focus == null && s.tasks.isEmpty) {
    focus = t('Henüz alışkanlık eklemedin. Bir tane ekle — küçük başla.',
        'You haven\'t added a habit yet. Add one — start small.');
  }

  return WeeklyReport(
    from: days.first,
    to: days.last,
    completionRate: completionRate,
    doneCount: doneTotal,
    possibleCount: possibleTotal,
    bestDay: bestDay,
    hardestDay: hardestDay,
    perfectDays: perfectDays,
    cleanDays: cleanDays,
    moneySaved: moneySaved,
    hoursSaved: hoursSaved,
    milestones: milestones,
    avgWaterCups: avgWater,
    focusSuggestion: focus,
  );
}
