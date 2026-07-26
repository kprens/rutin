/// Ana ekrandaki günlük motivasyon sözü havuzu.
///
/// Gerçek kişilere ait olmayan, uygulamanın kendi sesiyle (alışkanlık
/// bırakma, disiplin, küçük adımlar) yazılmış kısa aforizmalar — yanlış
/// atıf riskini önlemek için kimseye mal edilmemiştir.
///
/// [quoteOfTheDay] gün içinde SABİT kalır, gece yarısı otomatik değişir
/// (yılın günü % liste uzunluğu — ekstra state/kayıt gerekmez).
library;

class Quote {
  final String tr;
  final String en;
  const Quote(this.tr, this.en);
}

const List<Quote> motivationQuotes = [
  Quote('Vazgeçmediğin her gün seni biraz daha güçlü yapar.',
      'Every day you don\'t give in, you get a little stronger.'),
  Quote('Küçük adımlar, büyük değişimin tek yoludur.',
      'Small steps are the only road to big change.'),
  Quote('Bugün bıraktığın şey, yarının sağlıklı sen olur.',
      'What you quit today becomes tomorrow\'s healthier you.'),
  Quote('Motivasyon seni başlatır, alışkanlık seni bitirir.',
      'Motivation gets you started, habit keeps you going.'),
  Quote('Mükemmel gün değil, devam eden gün kazanır.',
      'Not the perfect day — the day you keep going wins.'),
  Quote('Bir isteği atlatmak, onu asla yaşamamaktan daha güçlüdür.',
      'Riding out one craving makes you stronger than never having one.'),
  Quote('Serini bozmak bir son değil, bugünün seçimidir — yarın yeniden başla.',
      'Breaking a streak isn\'t the end, just today\'s choice — start again tomorrow.'),
  Quote('Disiplin, kendine verdiğin en sessiz sevgidir.',
      'Discipline is the quietest form of self-love.'),
  Quote('Bugün yaptığın küçük şey, altı ay sonra büyük fark yaratır.',
      'The small thing you do today makes a big difference in six months.'),
  Quote('Rahatsızlık geçicidir; pişmanlık kalıcı olabilir.',
      'Discomfort is temporary; regret can last.'),
  Quote('Kendine karşı sabırlı ol — ilerleme düz bir çizgi değildir.',
      'Be patient with yourself — progress isn\'t a straight line.'),
  Quote('Bugünü say. Yarını say. Bir gün geriye bakıp gurur duyacaksın.',
      'Count today. Count tomorrow. One day you\'ll look back and be proud.'),
  Quote('Her "hayır" dediğin an, gerçek sana bir "evet"tir.',
      'Every time you say no, you\'re saying yes to who you really want to be.'),
  Quote('Alışkanlık, her gün attığın oyların toplamıdır.',
      'A habit is just the sum of the votes you cast every day.'),
  Quote('Bugün zor olabilir. Zor olması, yanlış yaptığın anlamına gelmez.',
      'Today might be hard. Hard doesn\'t mean you\'re doing it wrong.'),
  Quote('En iyi zaman bugündü, ikinci en iyi zaman şu an.',
      'The best time was today; the second-best time is right now.'),
  Quote('Vazgeçmek istediğin an, aslında en çok ilerlediğin andır.',
      'The moment you want to quit is the moment you\'re making progress.'),
  Quote('Kendinle yarış — dünkü senden biraz daha iyi ol, yeter.',
      'Race yourself — just be a little better than yesterday\'s you.'),
  Quote('Nefes al. Bu dalga da geçecek, hepsi geçti.',
      'Breathe. This wave will pass too — they all have.'),
  Quote('Güçlü olmak, hiç zorlanmamak değil, zorlanınca devam etmektir.',
      'Strength isn\'t never struggling — it\'s continuing anyway.'),
  Quote('Bugün attığın adım küçük görünebilir; yönü doğru.',
      'Today\'s step may look small; the direction is right.'),
  Quote('Kendine söz ver, sonra o sözü tut. Güven böyle inşa edilir.',
      'Make a promise to yourself, then keep it. That\'s how trust is built.'),
  Quote('Bir gün daha temiz, bir adım daha yakın.',
      'One more clean day, one step closer.'),
  Quote('Zorlandığın an değil, bıraktığın an kaybedersin.',
      'You don\'t lose in the struggle — you only lose if you quit.'),
  Quote('Bugünkü sen, yarınki alışkanlığını inşa ediyor.',
      'Today\'s you is building tomorrow\'s habit.'),
];

/// Gün içinde sabit, gece yarısı değişen "günün sözü" — yılın kaçıncı günü
/// olduğuna göre listede döner (ekstra state/kayıt gerekmez).
Quote quoteOfTheDay([DateTime? now]) {
  final d = now ?? DateTime.now();
  final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
  return motivationQuotes[dayOfYear % motivationQuotes.length];
}
