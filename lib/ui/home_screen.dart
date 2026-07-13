import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';
import 'achievements_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final todays = s.todaysTasks;
    final total = todays.length;
    final done = s.doneCount;
    final pct = total == 0 ? 0.0 : done / total;

    final name = s.userName.isNotEmpty
        ? s.userName.split(' ').first
        : t('Dostum', 'Friend');
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('Günaydın,', 'Good morning,')
        : hour < 18
            ? t('İyi günler,', 'Good afternoon,')
            : t('İyi akşamlar,', 'Good evening,');
    final dateStr = DateFormat('EEEE, MMMM d', T.locale).format(DateTime.now());

    final liters = s.water.count * 0.25;
    final goalL = s.water.goal * 0.25;
    final bestStreak = s.maxHabitStreak;
    final cleanDays =
        s.streaks.fold<int>(0, (m, st) => st.days > m ? st.days : m);

    return RScreen(
      children: [
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
                          style: const TextStyle(color: RC.purpleBright)),
                      const TextSpan(text: '👋'),
                    ]),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AchievementsScreen())),
              child: _iconBtn('🏆'),
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
                        style: const TextStyle(color: RC.muted, fontSize: 12)),
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
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: RC.text)),
                        TextSpan(
                            text: ' / $total',
                            style: const TextStyle(
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
                        valueColor: const AlwaysStoppedAnimation(RC.purple),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        t('${total - done} alışkanlık kaldı',
                            '${total - done} habits remaining'),
                        style: const TextStyle(color: RC.muted, fontSize: 13)),
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
            _stat('💧', '${liters.toStringAsFixed(1)}L',
                t('/ ${goalL.toStringAsFixed(1)}L', 'of ${goalL.toStringAsFixed(1)}L'),
                RC.blue, RC.tintBlue),
            const SizedBox(width: 12),
            _stat('🔥', '$bestStreak', t('en iyi\nseri', 'best\nstreak'),
                RC.amber, RC.tintAmber),
            const SizedBox(width: 12),
            _stat('💚', '${cleanDays}g', t('temiz', 'clean'), RC.teal,
                RC.tintGreen),
          ],
        ),
        const SizedBox(height: 26),

        // ---- Today's Habits ----
        _sectionHead(t("Bugünün Alışkanlıkları", "Today's Habits"),
            t('+ Ekle', '+ Add New'), RC.purpleBright,
            () => showHabitSheet(context)),
        const SizedBox(height: 12),
        if (todays.isEmpty)
          _empty(t('Bugün için alışkanlık yok. Yukarıdan ekle 👆',
              'No habits for today. Add one above 👆'))
        else
          ...todays.map((task) => _habitRow(context, s, task)),

        const SizedBox(height: 18),

        // ---- Recovery Progress ----
        _sectionHead(t('Bırakma İlerlemesi', 'Recovery Progress'),
            t('+ Ekle', '+ Add'), RC.teal, () => showRecoverySheet(context)),
        const SizedBox(height: 12),
        if (s.streaks.isEmpty)
          _empty(t('Bırakmak istediğin bir şey için kayıt ekle.',
              'Add a recovery for something you want to quit.'))
        else
          Row(
            children: [
              for (int i = 0; i < s.streaks.length && i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _recoveryMini(s.streaks[i])),
              ],
            ],
          ),
        const SizedBox(height: 18),

        // ---- Alıntı ----
        RCard(
          color: RC.tintPurple,
          border: RC.strokeSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  t('"Vazgeçmediğin her gün seni biraz daha güçlü yapar."',
                      '"Every day you don\'t give in, you get stronger."'),
                  style: const TextStyle(
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      color: RC.text,
                      height: 1.4)),
              const SizedBox(height: 12),
              Text(t('— Bilinmiyor', '— Unknown'), style: RText.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBtn(String emoji) => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.stroke),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      );

  Widget _stat(String emoji, String big, String sub, Color color, Color tint) {
    return Expanded(
      child: RCard(
        color: tint,
        border: RC.strokeSoft,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(big,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
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

  Widget _empty(String msg) => RCard(
        color: RC.card,
        border: RC.strokeSoft,
        child: Text(msg,
            style: const TextStyle(color: RC.muted, height: 1.5)),
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
                    Text(task.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                        streak > 0
                            ? t('🔥 $streak gün seri', '🔥 $streak day streak')
                            : (task.category.isNotEmpty
                                ? task.category
                                : t('Başlamaya hazır', 'Ready to start')),
                        style: const TextStyle(color: RC.muted, fontSize: 13)),
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
              leading: const Icon(Icons.edit_outlined, color: RC.purpleBright),
              title: Text(t('Düzenle', 'Edit'),
                  style: const TextStyle(color: RC.text)),
              onTap: () {
                Navigator.pop(sheetCtx);
                showHabitSheet(context, existing: task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: RC.red),
              title: Text(t('Sil', 'Delete'),
                  style: const TextStyle(color: RC.red)),
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

  Widget _recoveryMini(Streak r) {
    return RCard(
      radius: 18,
      color: RC.tintGreen,
      border: RC.strokeSoft,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recoveryEmojiFor(r), style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 12),
          Text(r.name, style: const TextStyle(color: RC.muted, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${r.days}',
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: RC.teal)),
          Text(t('gün temiz', 'days clean'),
              style: const TextStyle(color: RC.muted, fontSize: 13)),
          if (r.dailyCost > 0) ...[
            const SizedBox(height: 8),
            Text(t('₺${r.moneySaved.toStringAsFixed(0)} biriktin',
                '\$${r.moneySaved.toStringAsFixed(0)} saved'),
                style: const TextStyle(
                    color: RC.teal, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
