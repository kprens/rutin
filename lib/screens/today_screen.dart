import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

List<String> get _dowShort => T.en
    ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    : const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _controller = TextEditingController();
  final Set<int> _selectedDays = {0, 1, 2, 3, 4, 5, 6};

  void _add(AppState s) {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      toast(context, t('Görev adı yaz 🙂', 'Type a task name 🙂'));
      return;
    }
    if (_selectedDays.isEmpty) {
      toast(context, t('En az bir gün seç 🙂', 'Pick at least one day 🙂'));
      return;
    }
    final days = _selectedDays.length == 7 ? <int>[] : (_selectedDays.toList()..sort());
    s.addTask(name, days: days);
    _controller.clear();
    setState(() => _selectedDays.addAll({0, 1, 2, 3, 4, 5, 6}));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);
    final plan = s.todaysPlan();
    final todays = s.todaysTasks;
    final total = todays.length;
    final done = s.doneCount;
    final pct = total == 0 ? 0.0 : done / total;
    final otherDayCount = s.tasks.length - total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (plan.isNotEmpty) ...[
          SectionTitle(t('Bugünün Programı', "Today's Plan")),
          ...plan.map((p) => EventRow(
                time: p.time,
                name: p.name,
                tag: p.recurring ? '🔁' : '📌',
              )),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            SectionTitle(t('Bugünün Listesi', "Today's List")),
            const Spacer(),
            if (s.checklistStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(t('🔥 ${s.checklistStreak} gün seri', '🔥 ${s.checklistStreak}-day streak'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.accent2)),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('$done / $total tamamlandı', '$done / $total done'),
                  style: TextStyle(fontSize: 13, color: c.muted)),
              Text('${(pct * 100).round()}%',
                  style: TextStyle(fontSize: 13, color: c.muted)),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: c.card2,
            valueColor: AlwaysStoppedAnimation(c.green),
          ),
        ),
        const SizedBox(height: 14),
        if (todays.isEmpty)
          EmptyCard(t('Bugün için görev yok.\nAşağıdan ilk görevini ekle 👇', 'No tasks for today.\nAdd your first one below 👇'))
        else
          ...todays.map((task) {
            final isDone = s.todaysDone.contains(task.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => s.toggleTask(task),
                leading: Icon(
                  isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: isDone ? c.green : c.muted,
                ),
                title: Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 15,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? c.muted : c.text,
                  ),
                ),
                subtitle: task.days.isEmpty
                    ? null
                    : Text(task.days.map((d) => _dowShort[d]).join(', '),
                        style: TextStyle(fontSize: 11, color: c.muted)),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 18, color: c.muted),
                  onPressed: () {
                    s.deleteTask(task);
                    toastUndo(context, t('"${task.name}" silindi', '"${task.name}" deleted'), () => s.restoreTask(task));
                  },
                ),
              ),
            );
          }),
        if (otherDayCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(t('+ $otherDayCount görev başka günlerde', '+ $otherDayCount tasks on other days'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        if (total > 0 && done == total)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(t('🎉 Harika! Bugünün tüm görevlerini tamamladın.', "🎉 Amazing! You completed all of today's tasks."),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.green, fontSize: 14)),
          ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: t('Yeni görev ekle…', 'Add a new task…')),
                  onSubmitted: (_) => _add(s),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(7, (i) {
                    final on = _selectedDays.contains(i);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() {
                            if (on) {
                              _selectedDays.remove(i);
                            } else {
                              _selectedDays.add(i);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: on ? c.accent : c.card2,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              _dowShort[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: on ? Colors.white : c.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => _add(s), child: Text(t('＋ Görev Ekle', '＋ Add Task'))),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(t('Liste her gün otomatik sıfırlanır. Gün seçersen görev sadece o günler görünür.', 'The list resets daily. Pick days to show a task only on those days.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.muted)),
        ),
      ],
    );
  }
}
