/// "Geleceğe Mektup" — kullanıcının kendine yazdığı, neden bıraktığını
/// anlatan mesajı yazma/düzenleme ekranı.
///
/// Ürün mantığı: Bu özellik BİLEREK tamamen ücretsizdir.
/// Kullanıcının kendi sözlerini, üstelik en kırılgan anında (kriz) görmesini
/// paraya bağlamak hem etik olarak yanlış olurdu hem de özelliğin tüm gücünü
/// yok ederdi. İş değeri dönüşümden değil, bağlılıktan gelir: mektubunu
/// buraya bırakan kullanıcı uygulamayı silmez.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'water_screen.dart' show rutinAppBar;

class LetterScreen extends StatefulWidget {
  final Streak streak;
  const LetterScreen({super.key, required this.streak});

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.streak.letter);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AppState>().setStreakLetter(widget.streak, _ctrl.text);
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(_ctrl.text.trim().isEmpty
            ? t('Mektup silindi.', 'Letter removed.')
            : t('Mektubun kaydedildi. Zor bir anda karşına çıkacak.',
                'Your letter is saved. It will find you when things get hard.')),
        duration: const Duration(seconds: 4),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('Geleceğe Mektup', 'Letter to Future You')),
              const SizedBox(height: 18),

              RCard(
                color: RC.tintPurple,
                border: RC.purple.withValues(alpha: 0.25),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mark_email_unread_rounded,
                        size: 26, color: RC.purpleBright),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                          t('Bugün kararlısın. Ama zor bir an gelecek ve o an bunu hatırlamak zorlaşacak. Kendine şimdi yaz — o anda seni sen ikna edeceksin.',
                              'Today you feel certain. A hard moment will come when that certainty fades. Write to yourself now — you\'ll be the one who convinces you.'),
                          style: TextStyle(
                              color: RC.text, fontSize: 14, height: 1.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text(t('"${widget.streak.name}" için', 'For "${widget.streak.name}"'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RText.title),
              const SizedBox(height: 10),

              TextField(
                controller: _ctrl,
                maxLines: 10,
                minLines: 6,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: RC.text, height: 1.5),
                decoration: InputDecoration(
                  hintText: t(
                      'Neden bırakıyorsun? Kimin için? Bir yıl sonra nasıl biri olmak istiyorsun?',
                      'Why are you quitting? For whom? Who do you want to be a year from now?'),
                  hintStyle: TextStyle(color: RC.muted, height: 1.5),
                  filled: true,
                  fillColor: RC.card2,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: TextStyle(color: RC.muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: RC.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: RC.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: RC.purpleBright),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                  t('Bu mektup sadece sende kalır. Kriz anında ve zorlandığın günlerde karşına çıkar.',
                      'This letter stays with you. It appears when a craving hits or a day gets hard.'),
                  style: TextStyle(color: RC.muted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 20),

              RButton(t('Kaydet', 'Save'), onTap: _save),
            ],
          ),
        ),
      ),
    );
  }
}
