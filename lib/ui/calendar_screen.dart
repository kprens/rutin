import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'rutin_ui.dart';
import 'ui_logic.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selDate = todayKey();

  final _nameCtrl = TextEditingController();
  TimeOfDay? _time;
  bool _weekly = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _timeStr => _time == null
      ? ''
      : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

  int _colOf(DateTime d, bool mondayFirst) =>
      mondayFirst ? mondayIndex(d) : d.weekday % 7;

  Future<void> _pickTime() async {
    final tm = await showTimePicker(
        context: context, initialTime: _time ?? TimeOfDay.now());
    if (tm != null) setState(() => _time = tm);
  }

  void _addScheduleItem(AppState s) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast(t('Bir isim yaz 🙂', 'Type a name 🙂'));
      return;
    }
    final parts = _selDate.split('-').map(int.parse).toList();
    final sel = DateTime(parts[0], parts[1], parts[2]);
    if (_weekly) {
      s.addWeekly(mondayIndex(sel), _timeStr, name);
    } else {
      s.addEvent(_selDate, _timeStr, name);
    }
    _nameCtrl.clear();
    setState(() => _time = null);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final mondayFirst = s.weekStartsMonday;
    final y = _viewMonth.year, m = _viewMonth.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final leading = _colOf(DateTime(y, m, 1), mondayFirst);
    final tKey = todayKey();

    // Haftagünü başlıkları (tek harf, yerelleştirilmiş).
    final monRef = DateTime(2024, 1, 1); // Pazartesi
    final sunRef = DateTime(2023, 12, 31); // Pazar
    final weekdays = List.generate(7, (i) {
      final base = (mondayFirst ? monRef : sunRef).add(Duration(days: i));
      return DateFormat('EEEEE', T.locale).format(base);
    });

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final key =
          '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      cells.add(_day(s, d, key, tKey));
    }

    final streakHabits = s.tasks.toList()
      ..sort((a, b) => s.taskStreak(b).compareTo(s.taskStreak(a)));

    return RScreen(
      children: [
        const SizedBox(height: 8),
        Text(t('Takvim', 'Calendar'), style: RText.h1),
        const SizedBox(height: 6),
        Text(t('Alışkanlık geçmişin bir bakışta',
            'Your habit history at a glance'), style: RText.muted),
        const SizedBox(height: 20),

        // ---- Takvim kartı ----
        RCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                      onTap: () =>
                          setState(() => _viewMonth = DateTime(y, m - 1)),
                      child: _navBox(Icons.chevron_left)),
                  Text(DateFormat('MMMM yyyy', T.locale).format(_viewMonth),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  GestureDetector(
                      onTap: () =>
                          setState(() => _viewMonth = DateTime(y, m + 1)),
                      child: _navBox(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: weekdays
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(w.toUpperCase(),
                                style: const TextStyle(
                                    color: RC.faint,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: cells,
              ),
              const SizedBox(height: 16),
              const Divider(color: RC.stroke, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  _legend(RC.green.withValues(alpha: 0.25), RC.green,
                      t('Hepsi', 'All done')),
                  const SizedBox(width: 18),
                  _legend(RC.tintPurple, RC.purple, t('Kısmi', 'Partial')),
                  const SizedBox(width: 18),
                  _legend(Colors.transparent, RC.faint, t('Yok', 'No habits')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- Seçili günün programı (takvim + randevular) ----
        _scheduleSection(s),
        const SizedBox(height: 24),

        // ---- Active Streaks ----
        Text(t('Aktif Seriler', 'Active Streaks'), style: RText.title),
        const SizedBox(height: 12),
        if (streakHabits.isEmpty)
          RCard(
            border: RC.strokeSoft,
            child: Text(
                t('Henüz alışkanlık yok. Ana sayfadan ekle.',
                    'No habits yet. Add some from Home.'),
                style: const TextStyle(color: RC.muted, height: 1.5)),
          )
        else
          ...streakHabits.map((h) => _streakRow(s, h)),
      ],
    );
  }

  // ---------- Program bölümü ----------

  Widget _scheduleSection(AppState s) {
    final parts = _selDate.split('-').map(int.parse).toList();
    final sel = DateTime(parts[0], parts[1], parts[2]);
    final events = s.events.where((e) => e.date == _selDate).toList()
      ..sort((a, b) => _timeCompare(a.time, b.time));
    final weekly = s.weekly.where((w) => w.day == mondayIndex(sel)).toList()
      ..sort((a, b) => _timeCompare(a.time, b.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE, d MMMM', T.locale).format(sel),
            style: RText.title),
        const SizedBox(height: 12),
        if (events.isEmpty && weekly.isEmpty)
          RCard(
            border: RC.strokeSoft,
            child: Text(
                t('Bu gün için program yok. Aşağıdan ekle 👇',
                    'Nothing scheduled. Add below 👇'),
                style: const TextStyle(color: RC.muted, height: 1.5)),
          )
        else ...[
          ...events.map((e) => _scheduleRow(e.time, e.name, false, () {
                s.deleteEvent(e);
                _undo(t('"${e.name}" silindi', '"${e.name}" deleted'),
                    () => s.restoreEvent(e));
              })),
          ...weekly.map((w) => _scheduleRow(w.time, w.name, true, () {
                s.deleteWeekly(w);
                _undo(t('"${w.name}" silindi', '"${w.name}" deleted'),
                    () => s.restoreWeekly(w));
              })),
        ],
        const SizedBox(height: 12),
        // Ekleme kartı
        RCard(
          radius: 18,
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RC.card2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: RC.stroke),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 18, color: RC.purpleBright),
                          const SizedBox(width: 6),
                          Text(_time == null ? t('Saat', 'Time') : _timeStr,
                              style: const TextStyle(color: RC.text)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: RC.text),
                      decoration: InputDecoration(
                        hintText: t('örn. Tenis dersi', 'e.g. Tennis class'),
                        hintStyle: const TextStyle(color: RC.muted),
                        filled: true,
                        fillColor: RC.card2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: RC.stroke),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: RC.stroke),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _weekly = !_weekly),
                      child: Row(
                        children: [
                          RSwitch(
                              value: _weekly,
                              onChanged: (v) => setState(() => _weekly = v)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                                t('Her hafta tekrarla', 'Repeat weekly'),
                                style: const TextStyle(
                                    color: RC.muted, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _addScheduleItem(s),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: RG.purpleBtn,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(t('Ekle', 'Add'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _timeCompare(String a, String b) =>
      (a.isEmpty ? '99:99' : a).compareTo(b.isEmpty ? '99:99' : b);

  void _undo(String msg, VoidCallback onUndo) =>
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          action: SnackBarAction(
              label: t('Geri al', 'Undo'), onPressed: onUndo),
        ));

  Widget _scheduleRow(
          String time, String name, bool recurring, VoidCallback onDelete) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(time.isEmpty ? '—' : time,
                    style: const TextStyle(
                        color: RC.purpleBright,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 14, color: RC.text))),
              if (recurring)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('🔁', style: TextStyle(fontSize: 13)),
                ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close, size: 18, color: RC.muted),
              ),
            ],
          ),
        ),
      );

  // ---------- Takvim hücreleri ----------

  Widget _navBox(IconData icon) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RC.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RC.stroke),
        ),
        child: Icon(icon, color: RC.muted, size: 22),
      );

  Widget _day(AppState s, int d, String key, String tKey) {
    final doneCount = (s.doneByDate[key] ?? const <int>[]).length;
    final allDone = s.checklistFullDays.contains(key);
    final isToday = key == tKey;
    final isSel = key == _selDate;
    final isFuture = key.compareTo(tKey) > 0;

    Color? bg;
    Color border = Colors.transparent;
    Color textColor = RC.faint;
    bool dot = false;

    if (isSel) {
      bg = RC.purple;
      textColor = Colors.white;
    } else if (allDone) {
      bg = RC.green.withValues(alpha: 0.14);
      border = RC.greenDeep;
      textColor = RC.text;
      dot = true;
    } else if (doneCount > 0) {
      bg = RC.tintPurple;
      border = RC.purple.withValues(alpha: 0.45);
      textColor = RC.text;
    } else if (!isFuture) {
      textColor = RC.text;
    }
    if (isToday && !isSel) {
      border = RC.purpleBright;
    }

    return GestureDetector(
      onTap: () => setState(() => _selDate = key),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: isSel
              ? [BoxShadow(color: RC.purple.withValues(alpha: 0.5), blurRadius: 14)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('$d',
                style: TextStyle(
                    color: textColor,
                    fontWeight:
                        isSel ? FontWeight.w800 : FontWeight.w600)),
            if (dot)
              const Positioned(
                bottom: 6,
                child: CircleAvatar(radius: 2.5, backgroundColor: RC.green),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color fill, Color border, String label) => Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: border, width: 1.5),
            ),
          ),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: RC.muted, fontSize: 13)),
        ],
      );

  Widget _streakRow(AppState s, TaskItem h) {
    final streak = s.taskStreak(h);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            EmojiTile(habitEmojiFor(h), tint: habitTintFor(h)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                      h.category.isNotEmpty
                          ? h.category
                          : t('Alışkanlık', 'Habit'),
                      style: const TextStyle(color: RC.muted, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text('$streak',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: RC.amber)),
                  ],
                ),
                Text(t('gün seri', 'day streak'),
                    style: const TextStyle(color: RC.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
