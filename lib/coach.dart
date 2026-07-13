/// Kural tabanlı Rutin Koçu (V1) — API/LLM yok, maliyet 0.
/// Yalnızca cihazdaki gerçek geçmiş veriyi (görev tamamlama, su, streak,
/// checklist) analiz ederek kişiselleştirilmiş öneriler üretir.
///
/// İleride V2'de bu içgörüler bir LLM'e "bağlam" olarak verilebilir;
/// arayüz aynı [CoachTip] modelini kullanmaya devam eder.
library;

import 'l10n.dart';
import 'store.dart';

/// Önerinin tonu — arayüzde renk/ikon için.
enum CoachTone { positive, warning, info }

/// Tek bir koç önerisi.
class CoachTip {
  final String emoji;
  final String title;
  final String body;
  final CoachTone tone;

  /// Sıralama önceliği (büyük = üstte). Uyarılar genelde pozitiflerden yüksek.
  final int priority;

  const CoachTip({
    required this.emoji,
    required this.title,
    required this.body,
    this.tone = CoachTone.info,
    this.priority = 0,
  });
}

/// Geçerli bir epoch-ms id eşiği (~2017). Bunun altındaki id'ler için
/// oluşturma tarihi güvenilir sayılmaz.
const int _epochIdThreshold = 1500000000000;

DateTime _parseKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

List<String> get _weekdayNames => T.en
    ? const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ]
    : const [
        'Pazartesi',
        'Salı',
        'Çarşamba',
        'Perşembe',
        'Cuma',
        'Cumartesi',
        'Pazar'
      ];

/// Uygulama durumunu analiz edip önceliğe göre sıralı öneri listesi döndürür.
List<CoachTip> generateCoachTips(AppState s) {
  final tips = <CoachTip>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Veri başlangıcı: en eski kayıtlı gün. Kurulumdan önceki günleri
  // "kaçırılmış" saymamak için tüm pencereler bununla sınırlanır.
  final allKeys = <String>{...s.doneByDate.keys, ...s.waterByDate.keys};
  var dataStart = today;
  if (allKeys.isNotEmpty) {
    dataStart = allKeys.map(_parseKey).reduce((a, b) => a.isBefore(b) ? a : b);
  }
  final daysOfData = today.difference(dataStart).inDays;

  // ---------- SU: hafta içi vs hafta sonu hedef tutturma ----------
  final goal = s.water.goal;
  if (goal > 0 && daysOfData >= 5) {
    var weMet = 0, weTot = 0, wdMet = 0, wdTot = 0;
    for (var i = 1; i <= 42; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(dataStart)) break;
      final wd = mondayIndex(day);
      final met = (s.waterByDate[todayKey(day)] ?? 0) >= goal;
      if (wd >= 5) {
        weTot++;
        if (met) weMet++;
      } else {
        wdTot++;
        if (met) wdMet++;
      }
    }
    if (weTot >= 3 && wdTot >= 3) {
      final weRate = weMet / weTot;
      final wdRate = wdMet / wdTot;
      if (weRate < 0.4 && (wdRate - weRate) >= 0.25) {
        tips.add(CoachTip(
          emoji: '💧',
          tone: CoachTone.warning,
          priority: 60,
          title: t('Hafta sonları su hedefin düşüyor', 'Water dips on weekends'),
          body: t(
              'Hafta sonları su hedefini genelde tutturamıyorsun. Hafta sonu için biraz daha gerçekçi bir hedef belirlemeyi deneyebilirsin.',
              'You usually miss your water goal on weekends. Try setting a slightly more realistic goal for weekends.'),
        ));
      }
    }
  }

  // ---------- SU: son 7 gün ----------
  if (goal > 0 && daysOfData >= 3) {
    var sum = 0, n = 0;
    for (var i = 1; i <= 7; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(dataStart)) break;
      sum += s.waterByDate[todayKey(day)] ?? 0;
      n++;
    }
    if (n >= 3) {
      final avg = sum / n;
      if (avg < goal * 0.5) {
        tips.add(CoachTip(
          emoji: '🚰',
          tone: CoachTone.warning,
          priority: 54,
          title: t('Su takibin geride kaldı', 'Water is lagging'),
          body: s.water.intervalMinutes == 0
              ? t('Son günlerde ortalama ${avg.toStringAsFixed(0)}/$goal bardakta kaldın. Su sekmesinden hatırlatıcı açmak işini kolaylaştırır.',
                  'You averaged ${avg.toStringAsFixed(0)}/$goal glasses recently. Turning on reminders in the Water tab can help.')
              : t('Son günlerde ortalama ${avg.toStringAsFixed(0)}/$goal bardakta kaldın. Küçük ama sık yudumlar hedefe ulaşmayı kolaylaştırır.',
                  'You averaged ${avg.toStringAsFixed(0)}/$goal glasses recently. Small, frequent sips make the goal easier.'),
        ));
      } else if (avg >= goal * 0.9) {
        tips.add(CoachTip(
          emoji: '💧',
          tone: CoachTone.positive,
          priority: 20,
          title: t('Su hedefinde harikasın', "You're crushing your water goal"),
          body: t('Son bir haftada su hedefini düzenli tutturuyorsun. Böyle devam!',
              "You've hit your water goal consistently this week. Keep it up!"),
        ));
      }
    }
  }

  // ---------- GÖREV: güne özgü kaçırma paterni (amiral kural) ----------
  // Her görev için en fazla bir öneri: önce "belirli bir gün" paterni,
  // yoksa "genel olarak sürekli kaçırılıyor" kuralı.
  final taskTips = <CoachTip>[];
  for (final task in s.tasks) {
    var taskStart = dataStart;
    if (task.id > _epochIdThreshold) {
      final created = DateTime.fromMillisecondsSinceEpoch(task.id);
      final createdDay = DateTime(created.year, created.month, created.day);
      if (createdDay.isAfter(taskStart)) taskStart = createdDay;
    }

    final missByWd = List<int>.filled(7, 0);
    final actByWd = List<int>.filled(7, 0);
    for (var i = 1; i <= 42; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(dataStart)) break;
      if (day.isBefore(taskStart)) continue;
      final wd = mondayIndex(day);
      if (!task.activeOn(wd)) continue;
      actByWd[wd]++;
      final done = (s.doneByDate[todayKey(day)] ?? const <int>[]).contains(task.id);
      if (!done) missByWd[wd]++;
    }

    var worst = -1, worstMiss = 0;
    for (var wd = 0; wd < 7; wd++) {
      if (missByWd[wd] > worstMiss) {
        worstMiss = missByWd[wd];
        worst = wd;
      }
    }

    if (worst >= 0 &&
        worstMiss >= 3 &&
        actByWd[worst] >= 3 &&
        missByWd[worst] / actByWd[worst] >= 0.6) {
      taskTips.add(CoachTip(
        emoji: '📅',
        tone: CoachTone.warning,
        priority: 70 + worstMiss,
        title: t('${_weekdayNames[worst]} günleri zorlanıyorsun',
            'Struggling on ${_weekdayNames[worst]}'),
        body: t(
            'Son haftalarda "${task.name}" görevini genelde ${_weekdayNames[worst]} günleri kaçırıyorsun ($worstMiss kez). Bu görevi o gün için başka bir saate ya da başka bir güne almayı deneyebilirsin.',
            'Lately you usually miss "${task.name}" on ${_weekdayNames[worst]} ($worstMiss times). Try moving it to another day.'),
      ));
      continue;
    }

    // Genel kaçırma: son 7 aktif günün çoğu kaçtıysa.
    var act7 = 0, miss7 = 0;
    for (var i = 1; i <= 7; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(dataStart)) break;
      if (day.isBefore(taskStart)) continue;
      if (!task.activeOn(mondayIndex(day))) continue;
      act7++;
      final done =
          (s.doneByDate[todayKey(day)] ?? const <int>[]).contains(task.id);
      if (!done) miss7++;
    }
    if (act7 >= 4 && miss7 / act7 >= 0.7) {
      taskTips.add(CoachTip(
        emoji: '🎯',
        tone: CoachTone.warning,
        priority: 50,
        title: t('"${task.name}" arada kalıyor', '"${task.name}" keeps slipping'),
        body: t(
            '"${task.name}" son bir haftada pek işaretlenmedi ($miss7/$act7 gün kaçtı). Belki fazla iddialı — daha küçük bir adıma bölmeyi ya da sıklığını azaltmayı deneyebilirsin.',
            '"${task.name}" was rarely checked off this week (missed $miss7/$act7 days). Maybe it\'s too ambitious — try making it smaller or less frequent.'),
      ));
    }
  }
  taskTips.sort((a, b) => b.priority.compareTo(a.priority));
  tips.addAll(taskTips.take(3));

  // ---------- CHECKLIST serisi ----------
  final cstreak = s.checklistStreak;
  if (cstreak >= 3) {
    tips.add(CoachTip(
      emoji: '🔥',
      tone: CoachTone.positive,
      priority: 40,
      title: t('$cstreak günlük seri!', '$cstreak-day streak!'),
      body: t('$cstreak gündür günün tüm görevlerini bitiriyorsun. Momentumu kaybetme!',
          "You've finished all your daily tasks for $cstreak days straight. Don't lose the momentum!"),
    ));
  } else {
    var recentFull = 0;
    for (var i = 1; i <= 10; i++) {
      final day = today.subtract(Duration(days: i));
      if (s.checklistFullDays.contains(todayKey(day))) recentFull++;
    }
    if (recentFull >= 3) {
      tips.add(CoachTip(
        emoji: '💪',
        tone: CoachTone.info,
        priority: 44,
        title: t('Serini yeniden başlat', 'Restart your streak'),
        body: t('Son günlerde listeni tamamlama serin vardı ama araya girdi. Bugün listeyi bitirip yeniden başlayabilirsin.',
            'You had a nice completion streak recently but it broke. Finish today\'s list to start again.'),
      ));
    }
  }

  // ---------- Genel tamamlama trendi ----------
  if (daysOfData >= 10) {
    var last7 = 0, n1 = 0, prev7 = 0, n2 = 0;
    for (var i = 1; i <= 7; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(dataStart)) break;
      last7 += (s.doneByDate[todayKey(day)] ?? const <int>[]).length;
      n1++;
    }
    for (var i = 8; i <= 14; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(dataStart)) break;
      prev7 += (s.doneByDate[todayKey(day)] ?? const <int>[]).length;
      n2++;
    }
    if (n1 > 0 && n2 >= 4) {
      final a = last7 / n1;
      final b = prev7 / n2;
      if (b > 0.5 && a <= b * 0.6) {
        tips.add(CoachTip(
          emoji: '📉',
          tone: CoachTone.warning,
          priority: 36,
          title: t('Bu hafta biraz yavaşladın', 'A slower week'),
          body: t('Görev tamamlaman geçen haftaya göre düştü. Küçük başla — bugün sadece bir görevi bitir, gerisi gelir.',
              'Your task completion dropped versus last week. Start small — just finish one task today.'),
        ));
      } else if (b > 0 && a >= b * 1.4 && a >= 1) {
        tips.add(CoachTip(
          emoji: '📈',
          tone: CoachTone.positive,
          priority: 34,
          title: t('Yükselişteysin!', "You're on the rise!"),
          body: t('Bu hafta geçen haftaya göre çok daha üretkensin. Harika gidiyorsun!',
              "You're much more productive this week than last. Great job!"),
        ));
      }
    }
  }

  // ---------- Streak içgörüleri ----------
  final streakTips = <CoachTip>[];
  for (final st in s.streaks) {
    final d = st.days;
    if (d == 0 && st.bestDays >= 3) {
      streakTips.add(CoachTip(
        emoji: '🌱',
        tone: CoachTone.info,
        priority: 48,
        title: t('"${st.name}" yeniden başladı', '"${st.name}" restarted'),
        body: t('Düşüşler normal — en iyi serin ${st.bestDays} gündü, yeniden yakalayabilirsin. Kriz gelirse nefes egzersizini dene.',
            'Slips are normal — your best was ${st.bestDays} days, you can get there again. If a craving hits, try the breathing exercise.'),
      ));
    } else if (d >= 1) {
      final next = milestones.firstWhere((m) => m > d, orElse: () => 0);
      if (next > 0 && next - d <= 2) {
        streakTips.add(CoachTip(
          emoji: '🎯',
          tone: CoachTone.positive,
          priority: 32,
          title: t('"${st.name}" — kilometre taşına az kaldı',
              '"${st.name}" — milestone incoming'),
          body: t('$next güne sadece ${next - d} gün kaldı. Sıkı tutun!',
              'Only ${next - d} day(s) to $next days. Hang in there!'),
        ));
      } else if (st.dailyCost > 0 && st.moneySaved >= 10) {
        streakTips.add(CoachTip(
          emoji: '💰',
          tone: CoachTone.positive,
          priority: 24,
          title: t('"${st.name}" cebine para koyuyor',
              '"${st.name}" is saving you money'),
          body: t('Bırakalı ₺${st.moneySaved.toStringAsFixed(0)} biriktirdin ($d gün). Gurur duy!',
              "You've saved ₺${st.moneySaved.toStringAsFixed(0)} so far ($d days). Be proud!"),
        ));
      }
    }
  }
  streakTips.sort((a, b) => b.priority.compareTo(a.priority));
  tips.addAll(streakTips.take(2));

  // ---------- Boş durum / başlangıç önerileri ----------
  if (s.streaks.isEmpty) {
    tips.add(CoachTip(
      emoji: '🚭',
      tone: CoachTone.info,
      priority: 15,
      title: t('Bir sayaç başlat', 'Start a counter'),
      body: t('Bırakmak istediğin bir alışkanlık için streak sayacı aç — koç ilerlemeni takip edip destek versin.',
          'Add a streak counter for a habit you want to quit — the coach will track your progress and support you.'),
    ));
  }
  if (s.tasks.isEmpty) {
    tips.add(CoachTip(
      emoji: '📝',
      tone: CoachTone.info,
      priority: 15,
      title: t('İlk görevini ekle', 'Add your first task'),
      body: t('Bugün sekmesinden birkaç günlük görev ekle. Koç birkaç gün sonra alışkanlık paternlerini analiz etmeye başlar.',
          'Add a few daily tasks from the Today tab. The coach will start spotting patterns in a few days.'),
    ));
  }

  // ---------- Fallback ----------
  if (tips.isEmpty) {
    if (daysOfData < 3) {
      tips.add(CoachTip(
        emoji: '🌱',
        tone: CoachTone.info,
        priority: 5,
        title: t('Koç ısınıyor', 'Coach is warming up'),
        body: t('Birkaç gün veri topladıkça sana özel öneriler sunmaya başlayacağım. Kullanmaya devam et!',
            "As I gather a few days of data, I'll start giving you personalized tips. Keep going!"),
      ));
    } else {
      tips.add(CoachTip(
        emoji: '🎯',
        tone: CoachTone.positive,
        priority: 5,
        title: t('Her şey yolunda', 'All on track'),
        body: t('Şu an belirgin bir sorun görünmüyor — böyle istikrarlı devam et!',
            "Nothing stands out right now — keep up the steady work!"),
      ));
    }
  }

  tips.sort((a, b) => b.priority.compareTo(a.priority));
  return tips.length > 8 ? tips.sublist(0, 8) : tips;
}
