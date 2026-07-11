import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

List<String> get _dow => T.en
    ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    : const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
List<String> get _dowFull => T.en
    ? const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    : const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
List<String> get _months => T.en
    ? const ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December']
    : const ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

int _timeCompare(String a, String b) =>
    (a.isEmpty ? '99:99' : a).compareTo(b.isEmpty ? '99:99' : b);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _monthMode = false;
  int _selDay = mondayIndex(DateTime.now());
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selDate = todayKey();

  final _nameCtrl = TextEditingController();
  TimeOfDay? _pickedTime;

  String get _pickedTimeStr => _pickedTime == null
      ? ''
      : '${_pickedTime!.hour.toString().padLeft(2, '0')}:${_pickedTime!.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: _pickedTime ?? TimeOfDay.now());
    if (t != null) setState(() => _pickedTime = t);
  }

  void _addItem(AppState s) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      toast(context, t('Bir isim yaz 🙂', 'Type a name 🙂'));
      return;
    }
    if (_monthMode) {
      s.addEvent(_selDate, _pickedTimeStr, name);
      toast(context, t('📅 Randevu eklendi', '📅 Appointment added'));
    } else {
      s.addWeekly(_selDay, _pickedTimeStr, name);
      toast(context, t('📅 ${_dowFull[_selDay]} programına eklendi', '📅 Added to ${_dowFull[_selDay]} plan'));
    }
    _nameCtrl.clear();
    setState(() => _pickedTime = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = RutinColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(t('Takvim & Program', 'Calendar & Schedule')),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(t('Haftalık', 'Weekly'))),
            ButtonSegment(value: true, label: Text(t('Aylık', 'Monthly'))),
          ],
          selected: {_monthMode},
          onSelectionChanged: (v) => setState(() => _monthMode = v.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: c.card,
            selectedForegroundColor: c.accent2,
          ),
        ),
        const SizedBox(height: 14),
        if (!_monthMode) ..._buildWeekly(s, c) else ..._buildMonthly(s, c),
        _buildAddCard(s, c),
      ],
    );
  }

  // ---------- Haftalık ----------

  List<Widget> _buildWeekly(AppState s, RutinColors c) {
    final items = s.weekly.where((w) => w.day == _selDay).toList()
      ..sort((a, b) => _timeCompare(a.time, b.time));

    return [
      Row(
        children: List.generate(7, (i) {
          final active = i == _selDay;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selDay = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? c.accent : c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? c.accent : c.cardBorder),
                  ),
                  child: Text(
                    _dow[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : c.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 12),
      if (items.isEmpty)
        EmptyCard(t('${_dowFull[_selDay]} için program boş.\nOkul, spor, tenis, yüzme… aşağıdan ekle 👇', 'Nothing planned for ${_dowFull[_selDay]}.\nSchool, gym, tennis, swimming… add below 👇'))
      else
        ...items.map((w) => EventRow(
              time: w.time,
              name: w.name,
              onDelete: () {
                s.deleteWeekly(w);
                toastUndo(context, t('"${w.name}" silindi', '"${w.name}" deleted'), () => s.restoreWeekly(w));
              },
            )),
      const SizedBox(height: 4),
    ];
  }

  // ---------- Aylık ----------

  List<Widget> _buildMonthly(AppState s, RutinColors c) {
    final y = _viewMonth.year, m = _viewMonth.month;
    final firstOffset = mondayIndex(DateTime(y, m, 1));
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final tKey = todayKey();

    final parts = _selDate.split('-').map(int.parse).toList();
    final selDate = DateTime(parts[0], parts[1], parts[2]);
    final selEvents = s.events.where((e) => e.date == _selDate).toList()
      ..sort((a, b) => _timeCompare(a.time, b.time));
    final selWeekly = s.weekly.where((w) => w.day == mondayIndex(selDate)).toList()
      ..sort((a, b) => _timeCompare(a.time, b.time));

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        setState(() => _viewMonth = DateTime(y, m - 1)),
                  ),
                  Text('${_months[m - 1]} $y',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        setState(() => _viewMonth = DateTime(y, m + 1)),
                  ),
                ],
              ),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ..._dow.map((d) => Center(
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.muted)))),
                  ...List.generate(firstOffset, (_) => const SizedBox()),
                  ...List.generate(daysInMonth, (i) {
                    final d = i + 1;
                    final key =
                        '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
                    final hasEvent = s.events.any((e) => e.date == key);
                    final isSel = key == _selDate;
                    final isToday = key == tKey;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selDate = key),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSel ? c.accent : null,
                          borderRadius: BorderRadius.circular(10),
                          border: isToday && !isSel
                              ? Border.all(color: c.accent, width: 1.5)
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text('$d',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSel ? Colors.white : c.text)),
                            if (hasEvent)
                              Positioned(
                                bottom: 3,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSel ? Colors.white : c.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
      SectionTitle(
          '${selDate.day} ${_months[selDate.month - 1]} ${_dowFull[mondayIndex(selDate)]}'),
      if (selEvents.isEmpty && selWeekly.isEmpty)
        EmptyCard(t('Bu gün için kayıt yok.\nDiş randevusu, toplantı… aşağıdan ekle 👇', 'Nothing for this day.\nDentist, meeting… add below 👇'))
      else ...[
        ...selEvents.map((e) => EventRow(
              time: e.time,
              name: e.name,
              onDelete: () {
                s.deleteEvent(e);
                toastUndo(context, t('"${e.name}" silindi', '"${e.name}" deleted'), () => s.restoreEvent(e));
              },
            )),
        ...selWeekly
            .map((w) => EventRow(time: w.time, name: w.name, tag: t('🔁 Haftalık', '🔁 Weekly'))),
      ],
      const SizedBox(height: 4),
    ];
  }

  // ---------- Ekleme kartı ----------

  Widget _buildAddCard(AppState s, RutinColors c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_pickedTime == null ? t('Saat', 'Time') : _pickedTimeStr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent2,
                    side: BorderSide(color: c.cardBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                        hintText: _monthMode ? t('örn. Diş randevusu', 'e.g. Dentist appointment') : t('örn. Tenis dersi', 'e.g. Tennis class')),
                    onSubmitted: (_) => _addItem(s),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _addItem(s),
                child: Text(_monthMode ? t('＋ Randevu Ekle', '＋ Add Appointment') : t('＋ Haftalık Programa Ekle', '＋ Add to Weekly Plan')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _monthMode
                    ? t("Saatli randevulara 30 dk önce bildirim gelir; saatsizlere o gün 09:00'da.", 'Timed appointments notify 30 min ahead; untimed ones at 09:00 that day.')
                    : t('Seçili güne eklenir, her hafta tekrarlanır. Saatli olanlara 30 dk önce bildirim gelir.', 'Added to the selected day, repeats weekly. Timed items notify 30 min ahead.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
