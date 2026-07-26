/// Sağlık Geri Kazanım Zaman Çizelgesi.
///
/// Bırakılan maddeye/davranışa göre, bırakma anından itibaren geçen süreye
/// bağlı iyileşme kilometre taşları sunar ("72 saat: nikotin vücudundan
/// tamamen çıkar" gibi). Kullanıcıya somut, ölçülebilir ve UMUT VEREN bir
/// ilerleme anlatısı sağlar — bırakma uygulamalarında en çok bakılan ve
/// paylaşılan ekran tipik olarak budur.
///
/// ÖNEMLİ — TIBBİ SORUMLULUK:
/// Buradaki bilgiler GENEL ve BİLGİLENDİRME amaçlıdır; kişisel tıbbi tavsiye,
/// tanı veya tedavi DEĞİLDİR. Zaman aralıkları kişiden kişiye değişir.
/// Metinler bilinçli olarak kesin/iddialı değil, "genellikle / çoğu insanda"
/// tonunda yazılmıştır. UI, [medicalDisclaimer] metnini MUTLAKA göstermelidir
/// (App Store / Google Play sağlık içerik politikaları).
///
/// Veri statiktir: ağ isteği, AI ve çalışma zamanı maliyeti YOKTUR.
library;

import 'l10n.dart';

/// Bir iyileşme kilometre taşı.
class RecoveryMilestone {
  /// Bırakma anından itibaren geçmesi gereken süre.
  final Duration after;

  /// Kısa başlık (ör. "Nabız normale döner").
  final String titleTr;
  final String titleEn;

  /// Bir cümlelik açıklama.
  final String bodyTr;
  final String bodyEn;

  const RecoveryMilestone({
    required this.after,
    required this.titleTr,
    required this.titleEn,
    required this.bodyTr,
    required this.bodyEn,
  });

  String get title => t(titleTr, titleEn);
  String get body => t(bodyTr, bodyEn);
}

/// Bırakılan şeyin kategorisi. Kullanıcının seçtiği emoji/isimden türetilir
/// (bkz. [categoryFor]).
enum RecoveryCategory { nicotine, alcohol, sugar, caffeine, screen, generic }

/// Kullanıcının kaydından kategori tahmini.
///
/// Önce emoji (l10n.dart'taki hazır bağımlılık listesiyle birebir eşleşir),
/// sonra isim içindeki anahtar kelimeler denenir. Hiçbiri tutmazsa
/// [RecoveryCategory.generic] döner — yani HER kayıt için anlamlı bir
/// zaman çizelgesi gösterilir, hiçbir kullanıcı boş ekran görmez.
RecoveryCategory categoryFor({required String emoji, required String name}) {
  switch (emoji) {
    case '🚬':
    case '💨':
      return RecoveryCategory.nicotine;
    case '🍺':
      return RecoveryCategory.alcohol;
    case '🍬':
    case '🍫':
    case '🍔':
      return RecoveryCategory.sugar;
    case '☕':
    case '🥤':
      return RecoveryCategory.caffeine;
    case '📱':
    case '🎮':
    case '📺':
    case '🤳':
    case '🔞':
      return RecoveryCategory.screen;
  }

  final n = name.toLowerCase();
  bool has(List<String> keys) => keys.any(n.contains);

  if (has(['sigara', 'tütün', 'nikotin', 'smok', 'cigar', 'vape', 'nicotine'])) {
    return RecoveryCategory.nicotine;
  }
  if (has(['alkol', 'içki', 'bira', 'şarap', 'alcohol', 'beer', 'wine', 'drink'])) {
    return RecoveryCategory.alcohol;
  }
  if (has(['şeker', 'seker', 'tatlı', 'çikolata', 'sugar', 'sweet', 'candy', 'junk', 'fast food'])) {
    return RecoveryCategory.sugar;
  }
  if (has(['kafein', 'kahve', 'enerji', 'caffeine', 'coffee', 'energy'])) {
    return RecoveryCategory.caffeine;
  }
  if (has(['telefon', 'sosyal', 'oyun', 'ekran', 'porn', 'dizi', 'phone', 'social', 'game', 'screen', 'binge'])) {
    return RecoveryCategory.screen;
  }
  return RecoveryCategory.generic;
}

const _nicotine = <RecoveryMilestone>[
  RecoveryMilestone(
    after: Duration(minutes: 20),
    titleTr: 'Nabız ve tansiyon düşmeye başlar',
    titleEn: 'Heart rate and blood pressure start to drop',
    bodyTr: 'Son sigaradan sonraki ilk 20 dakikada nabzın normale dönmeye başlar.',
    bodyEn: 'Within 20 minutes of your last cigarette, your pulse begins returning to normal.',
  ),
  RecoveryMilestone(
    after: Duration(hours: 12),
    titleTr: 'Kandaki karbonmonoksit normale döner',
    titleEn: 'Carbon monoxide levels normalize',
    bodyTr: 'Kanın daha fazla oksijen taşımaya başlar; yorgunluk hissi azalabilir.',
    bodyEn: 'Your blood carries more oxygen again; fatigue often starts to ease.',
  ),
  RecoveryMilestone(
    after: Duration(hours: 72),
    titleTr: 'Nikotin vücuttan büyük ölçüde çıkar',
    titleEn: 'Nicotine has largely left your body',
    bodyTr: 'Fiziksel bağımlılığın en zor kısmı geride kalır. Bu genellikle en zorlu gündür — atlattıysan büyük iş.',
    bodyEn: 'The hardest part of physical dependence is behind you. This is often the toughest day — getting past it is a big deal.',
  ),
  RecoveryMilestone(
    after: Duration(days: 14),
    titleTr: 'Dolaşım ve nefes belirgin düzelir',
    titleEn: 'Circulation and breathing improve noticeably',
    bodyTr: 'Yürümek, merdiven çıkmak ve egzersiz çoğu insanda gözle görülür şekilde kolaylaşır.',
    bodyEn: 'Walking, stairs and exercise usually become noticeably easier.',
  ),
  RecoveryMilestone(
    after: Duration(days: 30),
    titleTr: 'Öksürük ve nefes darlığı azalır',
    titleEn: 'Coughing and shortness of breath decrease',
    bodyTr: 'Akciğerler kendini temizlemeye başlar; enerji seviyen genellikle yükselir.',
    bodyEn: 'Your lungs begin clearing themselves; energy levels typically rise.',
  ),
  RecoveryMilestone(
    after: Duration(days: 90),
    titleTr: 'Akciğer fonksiyonu iyileşir',
    titleEn: 'Lung function improves',
    bodyTr: 'Solunum kapasitesi çoğu kişide belirgin biçimde artar.',
    bodyEn: 'Breathing capacity increases noticeably for most people.',
  ),
  RecoveryMilestone(
    after: Duration(days: 365),
    titleTr: 'Kalp hastalığı riski önemli ölçüde azalır',
    titleEn: 'Heart disease risk drops substantially',
    bodyTr: 'Bir yılın sonunda kalp-damar riski, içmeye devam edenlere kıyasla kayda değer biçimde düşer.',
    bodyEn: 'After a year, cardiovascular risk falls considerably compared with continuing to smoke.',
  ),
];

const _alcohol = <RecoveryMilestone>[
  RecoveryMilestone(
    after: Duration(hours: 24),
    titleTr: 'Vücut kendini temizlemeye başlar',
    titleEn: 'Your body starts clearing itself',
    bodyTr: 'Kan şekeri ve sıvı dengesi düzelmeye başlar.',
    bodyEn: 'Blood sugar and hydration begin to stabilize.',
  ),
  RecoveryMilestone(
    after: Duration(days: 3),
    titleTr: 'Uyku kalitesi düzelmeye başlar',
    titleEn: 'Sleep quality begins to improve',
    bodyTr: 'Derin uyku evreleri geri gelmeye başlar; ilk günlerdeki huzursuzluk azalır.',
    bodyEn: 'Deep sleep stages start returning; early restlessness eases.',
  ),
  RecoveryMilestone(
    after: Duration(days: 7),
    titleTr: 'Cilt ve sıvı dengesi belirgin düzelir',
    titleEn: 'Skin and hydration visibly improve',
    bodyTr: 'Şişkinlik azalır, cilt tonu düzelir, sabahlar kolaylaşır.',
    bodyEn: 'Puffiness decreases, skin tone improves, mornings get easier.',
  ),
  RecoveryMilestone(
    after: Duration(days: 30),
    titleTr: 'Karaciğer yağlanması azalmaya başlar',
    titleEn: 'Liver fat begins to decrease',
    bodyTr: 'Bir aylık aradan sonra karaciğer değerlerinde iyileşme yaygın olarak görülür.',
    bodyEn: 'After a month, liver markers commonly show improvement.',
  ),
  RecoveryMilestone(
    after: Duration(days: 90),
    titleTr: 'Enerji ve odaklanma toparlanır',
    titleEn: 'Energy and focus recover',
    bodyTr: 'Zihinsel berraklık ve ruh hâli dengesi çoğu kişide belirgin biçimde artar.',
    bodyEn: 'Mental clarity and mood stability noticeably increase for most people.',
  ),
  RecoveryMilestone(
    after: Duration(days: 365),
    titleTr: 'Uzun vadeli sağlık riskleri düşer',
    titleEn: 'Long-term health risks decline',
    bodyTr: 'Bir yıllık ara, kalp ve karaciğer sağlığı açısından kayda değer bir kazanımdır.',
    bodyEn: 'A year off is a meaningful gain for heart and liver health.',
  ),
];

const _sugar = <RecoveryMilestone>[
  RecoveryMilestone(
    after: Duration(days: 3),
    titleTr: 'Şeker krizleri zayıflamaya başlar',
    titleEn: 'Sugar cravings start to weaken',
    bodyTr: 'İlk günler en zorudur — bu eşiği geçtiysen en sert kısım geride kaldı.',
    bodyEn: 'The first days are hardest — past this point the sharpest edge is behind you.',
  ),
  RecoveryMilestone(
    after: Duration(days: 7),
    titleTr: 'Enerji dalgalanmaları azalır',
    titleEn: 'Energy crashes even out',
    bodyTr: 'Öğleden sonra çöküşleri çoğu kişide belirgin şekilde hafifler.',
    bodyEn: 'Afternoon slumps noticeably ease for most people.',
  ),
  RecoveryMilestone(
    after: Duration(days: 21),
    titleTr: 'Tat algın değişir',
    titleEn: 'Your sense of taste shifts',
    bodyTr: 'Doğal yiyecekler daha tatlı gelmeye başlar; eski atıştırmalıklar aşırı tatlı gelir.',
    bodyEn: 'Natural foods start tasting sweeter; old snacks feel overwhelmingly sweet.',
  ),
  RecoveryMilestone(
    after: Duration(days: 90),
    titleTr: 'Metabolik göstergeler iyileşir',
    titleEn: 'Metabolic markers improve',
    bodyTr: 'Kan şekeri dengesi ve enerji sürekliliği uzun vadede belirgin biçimde düzelir.',
    bodyEn: 'Blood sugar balance and steady energy improve markedly over time.',
  ),
];

const _caffeine = <RecoveryMilestone>[
  RecoveryMilestone(
    after: Duration(days: 2),
    titleTr: 'Yoksunluk baş ağrısı zirveyi geçer',
    titleEn: 'Withdrawal headaches peak and pass',
    bodyTr: 'İlk 48 saat en zorudur; sonrası hızla kolaylaşır.',
    bodyEn: 'The first 48 hours are the hardest; it eases quickly after.',
  ),
  RecoveryMilestone(
    after: Duration(days: 7),
    titleTr: 'Uyku düzeni oturmaya başlar',
    titleEn: 'Sleep rhythm starts settling',
    bodyTr: 'Uykuya dalma süresi kısalır, gece uyanmaları azalır.',
    bodyEn: 'Falling asleep gets faster and night wakings decrease.',
  ),
  RecoveryMilestone(
    after: Duration(days: 21),
    titleTr: 'Doğal enerji dengesi kurulur',
    titleEn: 'Natural energy balance returns',
    bodyTr: 'Gün içi enerjin kafeine bağlı olmadan dengelenir.',
    bodyEn: 'Your daily energy stabilizes without relying on caffeine.',
  ),
];

const _screen = <RecoveryMilestone>[
  RecoveryMilestone(
    after: Duration(days: 3),
    titleTr: 'Otomatik uzanma refleksi zayıflar',
    titleEn: 'The reflex to reach for it weakens',
    bodyTr: 'İlk günlerde "boşluk" hissi normaldir; beynin yeni bir rutine geçiyor.',
    bodyEn: 'Feeling restless early on is normal; your brain is rewiring its routine.',
  ),
  RecoveryMilestone(
    after: Duration(days: 7),
    titleTr: 'Dikkat süresi uzamaya başlar',
    titleEn: 'Attention span starts stretching',
    bodyTr: 'Tek bir işe odaklanmak gözle görülür şekilde kolaylaşır.',
    bodyEn: 'Focusing on a single task becomes noticeably easier.',
  ),
  RecoveryMilestone(
    after: Duration(days: 30),
    titleTr: 'Uyku ve ruh hâli düzelir',
    titleEn: 'Sleep and mood improve',
    bodyTr: 'Özellikle akşam kullanımını bıraktıysan uyku kaliten belirgin artar.',
    bodyEn: 'Especially if you cut evening use, sleep quality rises noticeably.',
  ),
  RecoveryMilestone(
    after: Duration(days: 90),
    titleTr: 'Zamanın geri gelir',
    titleEn: 'You get your time back',
    bodyTr: 'Üç ayda biriken saatler, yeni bir beceri öğrenmeye yetecek kadar büyük bir yatırımdır.',
    bodyEn: 'The hours saved over three months are enough to learn a whole new skill.',
  ),
];

const _generic = <RecoveryMilestone>[
  RecoveryMilestone(
    after: Duration(days: 1),
    titleTr: 'İlk gün tamamlandı',
    titleEn: 'First day done',
    bodyTr: 'En zor adım başlamaktı — onu attın.',
    bodyEn: 'The hardest step was starting — you took it.',
  ),
  RecoveryMilestone(
    after: Duration(days: 3),
    titleTr: 'İlk eşik aşıldı',
    titleEn: 'First threshold cleared',
    bodyTr: 'İlk 72 saat çoğu vazgeçişin yaşandığı aralıktır. Sen geçtin.',
    bodyEn: 'The first 72 hours is where most people give up. You didn\'t.',
  ),
  RecoveryMilestone(
    after: Duration(days: 7),
    titleTr: 'Bir hafta',
    titleEn: 'One week',
    bodyTr: 'Artık bu bir karar değil, bir seri. Bozmak istemeyeceğin bir şeyin var.',
    bodyEn: 'This is no longer a decision — it\'s a streak. Now you have something to protect.',
  ),
  RecoveryMilestone(
    after: Duration(days: 21),
    titleTr: 'Yeni rutin oturuyor',
    titleEn: 'The new routine is settling',
    bodyTr: 'Bu noktada davranış, iradeden çok alışkanlıkla sürdürülmeye başlar.',
    bodyEn: 'By now the behaviour runs more on habit than on willpower.',
  ),
  RecoveryMilestone(
    after: Duration(days: 90),
    titleTr: 'Üç ay: kimlik değişimi',
    titleEn: 'Three months: identity shift',
    bodyTr: '"Bırakmaya çalışan biri" değil, "bırakmış biri" oldun.',
    bodyEn: 'You\'re no longer "someone trying to quit" — you\'re someone who quit.',
  ),
  RecoveryMilestone(
    after: Duration(days: 365),
    titleTr: 'Bir yıl',
    titleEn: 'One year',
    bodyTr: 'Bir yıl önceki sen bunu hayal ediyordu. Şimdi yaşıyorsun.',
    bodyEn: 'A year ago you were imagining this. Now you\'re living it.',
  ),
];

/// Kategoriye ait kilometre taşları (süreye göre artan sırada).
List<RecoveryMilestone> milestonesFor(RecoveryCategory c) {
  switch (c) {
    case RecoveryCategory.nicotine:
      return _nicotine;
    case RecoveryCategory.alcohol:
      return _alcohol;
    case RecoveryCategory.sugar:
      return _sugar;
    case RecoveryCategory.caffeine:
      return _caffeine;
    case RecoveryCategory.screen:
      return _screen;
    case RecoveryCategory.generic:
      return _generic;
  }
}

/// UI'da MUTLAKA gösterilmesi gereken sorumluluk reddi.
String get medicalDisclaimer => t(
    'Bu bilgiler geneldir ve tıbbi tavsiye değildir. Kişiden kişiye değişir; sağlık kararların için bir uzmana danış.',
    'This information is general and not medical advice. Individual experiences vary; consult a professional for health decisions.');

/// Bir kilometre taşına ulaşılana kadar kalan süreyi okunur biçimde verir.
String remainingLabel(Duration remaining) {
  if (remaining.inDays >= 1) {
    final d = remaining.inDays;
    return t('$d gün kaldı', '$d days left');
  }
  if (remaining.inHours >= 1) {
    final h = remaining.inHours;
    return t('$h saat kaldı', '$h hours left');
  }
  final m = remaining.inMinutes.clamp(1, 59);
  return t('$m dakika kaldı', '$m minutes left');
}

/// Kilometre taşının "ne zaman" etiketi (ör. "72 saat", "30 gün").
String whenLabel(Duration after) {
  if (after.inDays >= 365) {
    final y = after.inDays ~/ 365;
    return t('$y yıl', '$y year${y > 1 ? 's' : ''}');
  }
  if (after.inDays >= 1) {
    final d = after.inDays;
    return t('$d gün', '$d day${d > 1 ? 's' : ''}');
  }
  if (after.inHours >= 1) {
    final h = after.inHours;
    return t('$h saat', '$h hour${h > 1 ? 's' : ''}');
  }
  final m = after.inMinutes;
  return t('$m dakika', '$m minutes');
}
