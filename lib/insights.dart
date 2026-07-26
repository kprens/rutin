/// Kişisel içgörü motoru — Risk Penceresi ve Tetikleyici Haritası.
///
/// Kullanıcının [AppState.triggerLog] kayıtlarından (kriz/nüks anlarının
/// zamanı, tetikleyicisi ve sonucu) kişiye özel desenler çıkarır:
///   • Günün hangi saat aralığında ve haftanın hangi gününde risk altında
///   • Hangi tetikleyicinin baskın olduğu
///   • Hangi tetikleyicide dayanabildiği, hangisinde düştüğü
///
/// Bu, ürünün kopyalanması EN ZOR parçasıdır: rakip bir uygulama aynı
/// ekranı bir haftada yazabilir ama kullanıcının aylarca biriken kişisel
/// verisini kopyalayamaz. Değiştirme maliyetini (switching cost) yaratan
/// şey budur.
///
/// AI KULLANILMIYOR — saf istatistik. Ağ isteği, API maliyeti ve gecikme
/// yoktur; her şey cihazda, anında hesaplanır.
library;

import 'l10n.dart';
import 'models.dart';

/// Bir desenin gösterilebilmesi için gereken en az kayıt sayısı.
///
/// Bunun altında "3 nüksünün 2'si cuma akşamı" demek istatistiksel olarak
/// anlamsız ve kullanıcıyı yanıltıcı olurdu. Az veriyle kesin konuşan bir
/// ürün, ilk yanlış tahminde tüm güvenilirliğini kaybeder.
const kMinSamples = 4;

/// Tetikleyici anahtarının okunur adı.
String triggerLabel(String key) {
  switch (key) {
    case 'stress':
      return t('Stres', 'Stress');
    case 'boredom':
      return t('Can sıkıntısı', 'Boredom');
    case 'social':
      return t('Sosyal ortam', 'Social setting');
    case 'tired':
      return t('Yorgunluk', 'Tiredness');
    case 'anger':
      return t('Öfke / üzüntü', 'Anger / sadness');
    case 'habit':
      return t('Alışkanlık anı', 'Just habit');
    case 'celebration':
      return t('Kutlama', 'Celebration');
    default:
      return t('Başka', 'Something else');
  }
}

/// Riskin yoğunlaştığı zaman aralığı.
class RiskWindow {
  /// 0 = Pazartesi ... 6 = Pazar. null = belirgin bir gün deseni yok.
  final int? weekday;

  /// Riskin yoğunlaştığı saat aralığı (0–23).
  final int hourStart;
  final int hourEnd;

  /// Bu aralığa düşen kayıt sayısı ve toplam kayıt sayısı.
  final int hits;
  final int total;

  const RiskWindow({
    required this.weekday,
    required this.hourStart,
    required this.hourEnd,
    required this.hits,
    required this.total,
  });

  /// Kayıtların yüzde kaçı bu pencereye düşüyor.
  int get share => total == 0 ? 0 : (hits / total * 100).round();
}

/// Tek bir tetikleyici için özet.
class TriggerStat {
  final String key;
  final int count;

  /// Bu tetikleyicide kaç kez dayanıldı.
  final int survived;

  const TriggerStat({
    required this.key,
    required this.count,
    required this.survived,
  });

  /// Dayanma oranı (%). Kullanıcının hangi tetikleyicide güçlü, hangisinde
  /// kırılgan olduğunu gösterir.
  int get survivalRate => count == 0 ? 0 : (survived / count * 100).round();
}

/// Motorun tüm çıktısı.
class Insights {
  /// Analiz için yeterli veri var mı.
  final bool hasEnoughData;

  /// Şu ana kadar toplanan kayıt sayısı (yetersizse ilerleme göstermek için).
  final int sampleCount;

  final RiskWindow? riskWindow;

  /// Tetikleyiciler, çoktan aza sıralı.
  final List<TriggerStat> triggers;

  /// En sık görülen tetikleyici (varsa).
  TriggerStat? get dominant => triggers.isEmpty ? null : triggers.first;

  /// Kullanıcının en iyi dayandığı tetikleyici (en az 2 kayıtlı olanlar
  /// arasında). Güçlü yanını hatırlatmak için.
  TriggerStat? get strongest {
    final eligible = triggers.where((t0) => t0.count >= 2).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) => b.survivalRate.compareTo(a.survivalRate));
    return eligible.first;
  }

  /// En kırılgan olduğu tetikleyici (en az 2 kayıtlı olanlar arasında).
  TriggerStat? get weakest {
    final eligible = triggers.where((t0) => t0.count >= 2).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) => a.survivalRate.compareTo(b.survivalRate));
    return eligible.first;
  }

  const Insights({
    required this.hasEnoughData,
    required this.sampleCount,
    required this.riskWindow,
    required this.triggers,
  });
}

/// Haftanın günü adı (0 = Pazartesi).
String weekdayName(int index) {
  const tr = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  const en = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final i = index.clamp(0, 6);
  return t(tr[i], en[i]);
}

/// Saat aralığını okunur biçimde ("22:00–01:00") verir.
String hourRangeLabel(int start, int end) {
  String two(int h) => '${h.toString().padLeft(2, '0')}:00';
  return '${two(start)}–${two((end + 1) % 24)}';
}

/// Tüm içgörüleri hesaplar.
///
/// Bilerek [AppState] yerine doğrudan kayıt listesi alır: aksi halde
/// store.dart ↔ insights.dart arasında dairesel bir bağımlılık oluşurdu
/// (store, risk bildirimini kurmak için bu motoru çağırıyor). Ayrıca bu
/// haliyle motor saf bir fonksiyon — test edilmesi ve ileride başka bir
/// veri kaynağıyla beslenmesi kolay.
Insights computeInsights(List<TriggerEntry> log) {
  if (log.length < kMinSamples) {
    return Insights(
      hasEnoughData: false,
      sampleCount: log.length,
      riskWindow: null,
      triggers: const [],
    );
  }

  // ---- Tetikleyici dağılımı ----
  final counts = <String, int>{};
  final survivedCounts = <String, int>{};
  for (final e in log) {
    counts[e.trigger] = (counts[e.trigger] ?? 0) + 1;
    if (e.survived) {
      survivedCounts[e.trigger] = (survivedCounts[e.trigger] ?? 0) + 1;
    }
  }
  final triggers = counts.entries
      .map((e) => TriggerStat(
            key: e.key,
            count: e.value,
            survived: survivedCounts[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  // ---- Risk penceresi: 3 saatlik kayan pencere ----
  //
  // Her kayıt saatini sayıp, ardışık 3 saatlik pencereler içinde en yoğun
  // olanı seçiyoruz. Gece yarısını aşan pencereler (23–01 gibi) de doğru
  // yakalansın diye modülo ile dönüyoruz — nükslerin gece geç saatlerde
  // kümelenmesi bu üründe çok yaygın bir desendir ve tam da orada
  // kaybedilecek bir tespit olurdu.
  final byHour = List<int>.filled(24, 0);
  for (final e in log) {
    byHour[e.at.hour] += 1;
  }

  var bestStart = 0;
  var bestHits = -1;
  for (var start = 0; start < 24; start++) {
    var sum = 0;
    for (var k = 0; k < 3; k++) {
      sum += byHour[(start + k) % 24];
    }
    if (sum > bestHits) {
      bestHits = sum;
      bestStart = start;
    }
  }

  // ---- Gün deseni ----
  //
  // Bir gün, ancak kayıtların BELİRGİN biçimde orada toplandığında
  // gösterilir. Rastgele dağılmış veride "cuma günü riskli" demek uydurma
  // olurdu; eşik olarak "beklenenin en az iki katı" kullanılıyor
  // (7 güne eşit dağılım = toplam/7).
  final byWeekday = List<int>.filled(7, 0);
  for (final e in log) {
    byWeekday[(e.at.weekday - 1) % 7] += 1;
  }
  var bestDay = 0;
  for (var i = 1; i < 7; i++) {
    if (byWeekday[i] > byWeekday[bestDay]) bestDay = i;
  }
  final expectedPerDay = log.length / 7.0;
  final int? weekday =
      byWeekday[bestDay] >= expectedPerDay * 2 ? bestDay : null;

  return Insights(
    hasEnoughData: true,
    sampleCount: log.length,
    riskWindow: RiskWindow(
      weekday: weekday,
      hourStart: bestStart,
      hourEnd: (bestStart + 2) % 24,
      hits: bestHits,
      total: log.length,
    ),
    triggers: triggers,
  );
}

/// Kriz anında gösterilecek KİŞİSEL hatırlatma.
///
/// Genel bir motivasyon sözü değil, kullanıcının kendi geçmişinden çıkan
/// somut bir kanıt döndürür: "Bunu daha önce 4 kez atlattın." Kriz anında
/// en ikna edici şey, kişinin kendi başarısının kanıtıdır — çünkü
/// itiraz edilemez.
///
/// Yeterli veri yoksa null döner (uydurma bir istatistik göstermektense
/// hiçbir şey göstermemek doğrudur).
String? crisisEncouragement(List<TriggerEntry> log) {
  if (log.isEmpty) return null;
  final survived = log.where((e) => e.survived).length;
  if (survived <= 0) return null;

  if (survived >= 3) {
    return t(
        'Bu dalgayı daha önce $survived kez atlattın. Bu da geçecek.',
        'You\'ve ridden out this wave $survived times before. This one passes too.');
  }
  return t('Bunu daha önce başardın. Şu an yeni bir şey istenmiyor senden.',
      'You\'ve done this before. Nothing new is being asked of you right now.');
}

/// Risk penceresini tek cümlelik, insan diliyle anlatır.
String riskSentence(RiskWindow w) {
  final range = hourRangeLabel(w.hourStart, w.hourEnd);
  if (w.weekday != null) {
    return t(
        'Zorlandığın anların %${w.share}\'i ${weekdayName(w.weekday!)} günleri, $range arasında yoğunlaşıyor.',
        '${w.share}% of your hard moments cluster on ${weekdayName(w.weekday!)}, between $range.');
  }
  return t(
      'Zorlandığın anların %${w.share}\'i $range saatleri arasında yoğunlaşıyor.',
      '${w.share}% of your hard moments cluster between $range.');
}
