/// Tek dokunuşluk tetikleyici anketi.
///
/// Bir kriz atlatıldıktan ya da nüks kaydedildikten SONRA açılır ve tek bir
/// soru sorar: "Bunu ne tetikledi?". Cevap [AppState.addTriggerEntry] ile
/// zaman damgasıyla kaydedilir; bu kayıtlar ileride kişisel tetikleyici
/// haritası ve risk penceresi tahmini için tek veri kaynağıdır.
///
/// Tasarım kuralları (bilerek katı):
///  • ASLA kriz anında sorulmaz — yalnızca kriz bittikten sonra.
///  • Tek soru, tek dokunuş. Metin girişi, çoklu seçim, "devam" butonu yok.
///  • Her zaman atlanabilir; atlamak da bir cevap kadar meşrudur.
///  • Nüks sonrası ton asla suçlayıcı değildir.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'rutin_ui.dart';

/// Seçenekler: (anahtar, ikon, TR, EN)
const _options = <(String, IconData, String, String)>[
  ('stress', Icons.bolt_rounded, 'Stres', 'Stress'),
  ('boredom', Icons.hourglass_empty_rounded, 'Can sıkıntısı', 'Boredom'),
  ('social', Icons.groups_rounded, 'Sosyal ortam', 'Social setting'),
  ('tired', Icons.bedtime_rounded, 'Yorgunluk', 'Tiredness'),
  ('anger', Icons.mood_bad_rounded, 'Öfke / üzüntü', 'Anger / sadness'),
  ('habit', Icons.repeat_rounded, 'Alışkanlık anı', 'Just habit'),
  ('celebration', Icons.celebration_rounded, 'Kutlama', 'Celebration'),
  ('other', Icons.more_horiz_rounded, 'Başka', 'Something else'),
];

/// Anketi açar. [survived] true ise kriz atlatıldı, false ise nüksedildi.
///
/// Hiçbir şey döndürmez ve hiçbir akışı bloklamaz — kullanıcı kapatırsa
/// sessizce geçilir.
Future<void> askTrigger(
  BuildContext context, {
  required Streak streak,
  required bool survived,
}) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: RC.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => _TriggerSheet(streak: streak, survived: survived),
  );
}

class _TriggerSheet extends StatelessWidget {
  final Streak streak;
  final bool survived;

  const _TriggerSheet({required this.streak, required this.survived});

  void _pick(BuildContext context, String key) {
    context.read<AppState>().addTriggerEntry(
          streakId: streak.id,
          trigger: key,
          survived: survived,
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(t('Not edildi. Bu, desenini görmemize yardım edecek.',
            'Noted. This helps us spot your pattern.')),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RC.stroke,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
                survived
                    ? t('Bunu ne tetiklemişti?', 'What set that off?')
                    : t('Bu sefer ne tetikledi?', 'What triggered it this time?'),
                style: TextStyle(
                    color: RC.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                survived
                    ? t('Tek dokunuş. Desenini çıkarmamıza yardım eder.',
                        'One tap. It helps us find your pattern.')
                    : t('Yargı yok — sadece bir sonrakine hazırlanmak için.',
                        'No judgment — just so we can prepare for next time.'),
                style: TextStyle(color: RC.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (key, icon, tr, en) in _options)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pick(context, key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: RC.card2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RC.stroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 17, color: RC.purpleBright),
                          const SizedBox(width: 8),
                          Text(t(tr, en),
                              style: TextStyle(
                                  color: RC.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('Şimdi değil', 'Not now'),
                    style: TextStyle(color: RC.muted, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
