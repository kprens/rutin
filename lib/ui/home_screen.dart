import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../quotes.dart';
import '../store.dart';
import 'home_logic.dart';
import 'recovery_timeline_screen.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'achievements_screen.dart';
import 'water_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final todays = s.todaysTasks;
    final total = todays.length;
    final done = s.doneCount;
    final pct = progressRatio(done, total);

    final name = s.userName.isNotEmpty
        ? s.userName.split(' ').first
        : t('Dostum', 'Friend');
    final greeting = greetingFor(DateTime.now().hour);
    final dateStr = DateFormat('EEEE, MMMM d', T.locale).format(DateTime.now());

    // Gerçek loglanan ml toplamından — yuvarlanmış bardak sayısından DEĞİL
    // (bkz. water_screen.dart'taki aynı düzeltme; kullanıcıların bildirdiği
    // "matematik hatası" buydu).
    final liters = s.todaysWaterMl / 1000;
    final goalL = s.water.goal * 0.25;
    final bestStreak = s.maxHabitStreak;
    final cleanDays = longestCleanStreak(s.streaks);
    final dailyQuote = quoteOfTheDay();
    // Sık kaçırılan alışkanlık için "hedefi küçültelim mi?" önerisi
    // (bkz. _adaptiveCard). Bir kez hesaplanır.
    final adaptive = s.adaptiveSuggestion();

    return RScreen(
      children: [
        // Yükleme başarısız olduysa EN ÜSTTE uyar. Bu şerit olmadan kullanıcı
        // yalnızca boş bir ana ekran görür ve verisinin silindiğini sanar —
        // kategorideki en sık 1 yıldız sebebi budur.
        if (s.dataUnavailable)
          DataUnavailableBanner(onRetry: () => s.retryLoad()),

        // ---- Başlık ----
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(dateStr, style: RText.muted),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(style: RText.h1, children: [
                      TextSpan(text: '$greeting\n'),
                      TextSpan(
                          text: '$name ',
                          style: TextStyle(color: RC.purpleBright)),
                      WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.waving_hand_rounded,
                              size: 22, color: RC.amber)),
                    ]),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AchievementsScreen())),
              child: _iconBtn(Icons.emoji_events_rounded),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // ---- İlerleme kartı ----
        RCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              ProgressRing(
                value: pct,
                size: 108,
                stroke: 9,
                color: RC.purple,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(pct * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(t('Bitti', 'Done'),
                        style: TextStyle(color: RC.muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                            text: '$done',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: RC.text)),
                        TextSpan(
                            text: ' / $total',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: RC.muted)),
                      ]),
                    ),
                    Text(t('alışkanlık tamam', 'habits completed'),
                        style: RText.muted),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: RC.card2,
                        valueColor: AlwaysStoppedAnimation(RC.purple),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        t('${habitsRemaining(done, total)} alışkanlık kaldı',
                            '${habitsRemaining(done, total)} habits remaining'),
                        style: TextStyle(color: RC.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- 3 stat chip ----
        Row(
          children: [
            _stat(Icons.water_drop_rounded, '${liters.toStringAsFixed(1)}L',
                t('/ ${goalL.toStringAsFixed(1)}L', 'of ${goalL.toStringAsFixed(1)}L'),
                RC.blue, RC.tintBlue),
            const SizedBox(width: 12),
            _stat(Icons.local_fire_department_rounded, '$bestStreak', t('en iyi\nseri', 'best\nstreak'),
                RC.amber, RC.tintAmber),
            const SizedBox(width: 12),
            _stat(Icons.favorite_rounded, '${cleanDays}g', t('temiz', 'clean'), RC.teal,
                RC.tintGreen),
          ],
        ),
        const SizedBox(height: 14),

        // ---- Su (hızlı ekle) ----
        _waterQuickCard(context, s),
        const SizedBox(height: 26),

        // ---- Today's Habits ----
        _sectionHead(t("Bugünün Alışkanlıkları", "Today's Habits"),
            t('+ Ekle', '+ Add New'), RC.purpleBright,
            () => showHabitSheet(context)),
        const SizedBox(height: 12),
        if (todays.isEmpty)
          REmpty(
            icon: Icons.checklist_rounded,
            title: t('Bugün için alışkanlık yok', 'No habits for today'),
            message: t('İlk alışkanlığını ekle; günlük ilerlemen burada görünecek.',
                'Add your first habit — your daily progress will show up here.'),
            actionLabel: t('Alışkanlık Ekle', 'Add Habit'),
            onAction: () => showHabitSheet(context),
          )
        else
          ...todays.map((task) => _habitRow(context, s, task)),

        // ---- Adaptif zorluk önerisi ----
        // Sık kaçırılan bir alışkanlık varsa, uygulama kullanıcıyı
        // suçlamak yerine hedefi küçültmeyi önerir. Kategorideki en büyük
        // terk sebebi başarısızlık utancıdır: insanlar beceremediklerinde
        // uygulamayı silerler. Rakipler burada ceza mekaniği kurar
        // (kırık seri, kırmızı işaretler); biz uyarlanma öneriyoruz.
        // Tek çağrı: adaptiveSuggestion() her alışkanlık için 7 günlük bir
        // döngü çalıştırıyor; iki kez çağırmak bu işi gereksiz yere
        // ikiye katlardı (ve iki çağrı arasında gün dönerse tutarsız
        // sonuç verebilirdi).
        if (adaptive != null) ...[
          const SizedBox(height: 12),
          _adaptiveCard(context, s, adaptive),
        ],

        const SizedBox(height: 18),

        // ---- Recovery Progress ----
        _sectionHead(t('Bırakma İlerlemesi', 'Recovery Progress'),
            t('+ Ekle', '+ Add'), RC.teal, () => showRecoverySheet(context)),
        const SizedBox(height: 12),
        if (s.streaks.isEmpty)
          REmpty(
            icon: Icons.spa_rounded,
            title: t('Henüz bırakma kaydın yok', 'No recoveries yet'),
            message: t('Bırakmak istediğin bir şeyi ekle; temiz günlerini buradan takip et.',
                "Add something you want to quit — track your clean days here."),
            actionLabel: t('Kayıt Ekle', 'Add Recovery'),
            onAction: () => showRecoverySheet(context),
          )
        else
          Row(
            children: [
              for (int i = 0; i < s.streaks.length && i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _recoveryMini(context, s.streaks[i])),
              ],
            ],
          ),
        const SizedBox(height: 18),

        // ---- Günün Sözü (her gün otomatik değişir, bkz. quotes.dart) ----
        RCard(
          color: RC.tintPurple,
          border: RC.strokeSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${t(dailyQuote.tr, dailyQuote.en)}"',
                  style: TextStyle(
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      color: RC.text,
                      height: 1.4)),
              const SizedBox(height: 12),
              Text(t('Günün Sözü', 'Quote of the Day'), style: RText.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon) => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.stroke),
        ),
        child: Icon(icon, size: 22, color: RC.amber),
      );

  Widget _stat(IconData icon, String big, String sub, Color color, Color tint) {
    return Expanded(
      child: RCard(
        color: tint,
        border: RC.strokeSoft,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(big,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    color: RC.muted, fontSize: 12, height: 1.15)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHead(
          String title, String action, Color actionColor, VoidCallback onTap) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: RText.title),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text(action,
                style: TextStyle(
                    color: actionColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ],
      );

  Widget _habitRow(BuildContext context, AppState s, TaskItem task) {
    final done = s.todaysDone.contains(task.id);
    final streak = s.taskStreak(task);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RCard(
        radius: 18,
        border: done ? RC.purple.withValues(alpha: 0.4) : RC.stroke,
        color: done ? RC.tintPurple : RC.card,
        padding: const EdgeInsets.all(14),
        onTap: () => s.toggleTask(task),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _habitActions(context, s, task),
          child: Row(
            children: [
              EmojiTile(habitEmojiFor(task), tint: habitTintFor(task)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // maxLines/ellipsis: kullanıcı uzun bir alışkanlık adı
                    // yazdığında satırın taşıp "kayan yazı"/overflow şeridi
                    // oluşturmasını engeller.
                    Text(task.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                        streak > 0
                            ? t('🔥 $streak gün seri', '🔥 $streak day streak')
                            : (task.category.isNotEmpty
                                ? task.category
                                : t('Başlamaya hazır', 'Ready to start')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: RC.muted, fontSize: 13)),
                  ],
                ),
              ),
              _check(done),
            ],
          ),
        ),
      ),
    );
  }

  void _habitActions(BuildContext context, AppState s, TaskItem task) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: RC.purpleBright),
              title: Text(t('Düzenle', 'Edit'),
                  style: TextStyle(color: RC.text)),
              onTap: () {
                Navigator.pop(sheetCtx);
                showHabitSheet(context, existing: task);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: RC.red),
              title: Text(t('Sil', 'Delete'),
                  style: TextStyle(color: RC.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                s.deleteTask(task);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                    content: Text(t('"${task.name}" silindi', '"${task.name}" deleted')),
                    action: SnackBarAction(
                        label: t('Geri al', 'Undo'),
                        onPressed: () => s.restoreTask(task)),
                  ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _check(bool done) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: done ? RC.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: done ? RC.purple : RC.faint, width: 2),
        ),
        child: done
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      );

  /// Ana ekrandan hızlı su ekleme/iptal — önceden yalnızca Su Takibi
  /// ekranından (Profil > Su Takibi) yapılabiliyordu. Son eklenen kaydı
  /// doğrudan burada da geri alabilirsin.
  Widget _waterQuickCard(BuildContext context, AppState s) {
    final log = s.todaysWaterLog;
    final last = log.isEmpty ? null : log.first;
    return RCard(
      color: RC.tintBlue,
      border: RC.blue.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, size: 20, color: RC.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t('Su İç', 'Drink Water'), style: RText.title),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WaterScreen())),
                child: Text(t('Tümü →', 'All →'),
                    style: TextStyle(
                        color: RC.blue, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final ml in [150, 250, 500]) ...[
                Expanded(child: _waterQuickBtn(s, ml)),
                if (ml != 500) const SizedBox(width: 10),
              ],
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                      t('Son: ${last.ml}ml · ${last.time}',
                          'Last: ${last.ml}ml · ${last.time}'),
                      style: TextStyle(color: RC.muted, fontSize: 13)),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => s.removeWaterLog(last),
                  child: Text(t('İptal Et', 'Undo'),
                      style: TextStyle(
                          color: RC.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _waterQuickBtn(AppState s, int ml) => GestureDetector(
        onTap: () => s.addWaterMl(ml),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RC.card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RC.blue.withValues(alpha: 0.3)),
          ),
          child: Text('+${ml}ml',
              style: TextStyle(
                  color: RC.blue, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      );

  /// "Hedefini küçültelim mi?" kartı.
  ///
  /// Ton kritik: asla "başaramadın" demez. Küçültmek bir yenilgi değil,
  /// akıllı bir strateji olarak sunulur — çünkü gerçekten öyledir.
  Widget _adaptiveCard(BuildContext context, AppState s, TaskItem task) {
    return RCard(
      color: RC.tintBlue,
      border: RC.blue.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: RC.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t('Bunu birlikte kolaylaştıralım mı?',
                    'Shall we make this easier together?'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: RC.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              t('"${task.name}" bu hafta sık kaçtı. Hedefi küçültmek yenilgi değil — küçük ama tuttuğun bir alışkanlık, büyük ama tutmadığından çok daha değerli.',
                  '"${task.name}" slipped a lot this week. Shrinking the goal isn\'t failure — a small habit you keep beats a big one you don\'t.'),
              style: TextStyle(color: RC.muted, fontSize: 13, height: 1.45)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showHabitSheet(context, existing: task),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: RG.blueBtn,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(t('Hedefi düzenle', 'Adjust goal'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => s.dismissAdaptiveSuggestion(task),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RC.card2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RC.stroke),
                  ),
                  child: Text(t('Böyle kalsın', 'Keep it'),
                      style: TextStyle(
                          color: RC.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recoveryMini(BuildContext context, Streak r) {
    return RCard(
      radius: 18,
      color: RC.tintGreen,
      border: RC.strokeSoft,
      padding: const EdgeInsets.all(16),
      // İyileşme zaman çizelgesine kısayol (bkz. recovery_timeline_screen.dart).
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RecoveryTimelineScreen(streak: r))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recoveryEmojiFor(r), style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 12),
          Text(r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: RC.muted, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${r.days}',
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: RC.teal)),
          Text(t('gün temiz', 'days clean'),
              style: TextStyle(color: RC.muted, fontSize: 13)),
          if (r.dailyCost > 0) ...[
            const SizedBox(height: 8),
            Text(t('₺${r.moneySaved.toStringAsFixed(0)} biriktin',
                '\$${r.moneySaved.toStringAsFixed(0)} saved'),
                style: TextStyle(
                    color: RC.teal, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
