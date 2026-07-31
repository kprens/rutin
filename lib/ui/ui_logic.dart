/// Yeni koyu arayüzü gerçek [AppState]'e bağlayan yardımcı katman.
///
/// - Görsel türetmeler (emoji, tint) — sample_data yerine gerçek modeller.
/// - Ekle/düzenle alt sayfaları (habit + recovery) — tüm CRUD buradan.
/// - SOS akışı — kriz ekranını açar.
/// - Başarım (achievements) değerlendirici — gerçek veriden rozet durumu.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import 'crisis_screen.dart';
import 'rutin_ui.dart';

// ------------------------- GÖRSEL TÜRETMELER -------------------------

final _habitTints = <Color>[
  RC.tintPurple,
  RC.tintGreen,
  RC.tintAmber,
  RC.tintBlue,
  RC.tintPink,
  RC.tintTeal,
];

/// Görev için sabit ama çeşitli bir tint (id'ye göre).
Color habitTintFor(TaskItem t) => _habitTints[t.id.abs() % _habitTints.length];

/// Görev avatar emojisi (yoksa varsayılan).
String habitEmojiFor(TaskItem t) => t.emoji.isNotEmpty ? t.emoji : '✅';

/// Recovery avatar emojisi: kayıtlı emoji > preset eşleşmesi > varsayılan.
String recoveryEmojiFor(Streak s) {
  if (s.emoji.isNotEmpty) return s.emoji;
  final lower = s.name.trim().toLowerCase();
  for (final p in addictionPresets()) {
    if (p.$2.toLowerCase() == lower) return p.$1;
  }
  return '💪';
}

/// Bir sonraki kilometre taşı (milestone) ve etiketi.
({int target, String label}) nextMilestone(int days) {
  final next = milestones.firstWhere((m) => m > days, orElse: () => 0);
  if (next == 0) {
    return (target: days == 0 ? 1 : days, label: t('Efsane', 'Legend'));
  }
  return (target: next, label: t('$next Gün', '$next Days'));
}

/// Habit ekleme/düzenlemede seçilebilen emojiler.
const habitEmojiChoices = <String>[
  '✅', '🧘', '🏃', '📚', '🚿', '✍️', '💧', '🥗',
  '😴', '🧠', '💪', '🎯', '🎨', '🎸', '🙏', '🚶',
];

// ------------------------- EKLE / DÜZENLE: HABIT -------------------------

/// Görev (habit) ekleme veya düzenleme alt sayfası.
Future<void> showHabitSheet(BuildContext context, {TaskItem? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HabitSheet(existing: existing),
  );
}

class _HabitSheet extends StatefulWidget {
  final TaskItem? existing;
  const _HabitSheet({this.existing});
  @override
  State<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<_HabitSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late String _emoji;
  late Set<int> _days;

  List<String> get _dow => T.en
      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
      : const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _emoji = e != null && e.emoji.isNotEmpty ? e.emoji : habitEmojiChoices.first;
    _days = e == null || e.days.isEmpty
        ? {0, 1, 2, 3, 4, 5, 6}
        : e.days.toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  void _save() {
    final s = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(t('Bir isim yaz 🙂', 'Type a name 🙂'));
      return;
    }
    if (_days.isEmpty) {
      _toast(t('En az bir gün seç 🙂', 'Pick at least one day 🙂'));
      return;
    }
    final days = _days.length == 7 ? <int>[] : (_days.toList()..sort());
    final cat = _category.text.trim();
    if (widget.existing == null) {
      s.addTask(name, days: days, emoji: _emoji, category: cat);
    } else {
      s.editTask(widget.existing!,
          name: name, days: days, emoji: _emoji, category: cat);
    }
    Navigator.pop(context);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return _SheetScaffold(
      title: editing ? t('Alışkanlığı Düzenle', 'Edit Habit') : t('Yeni Alışkanlık', 'New Habit'),
      children: [
        _FieldLabel(t('Emoji', 'Emoji')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: habitEmojiChoices.map((em) {
            final on = em == _emoji;
            return GestureDetector(
              onTap: () => setState(() => _emoji = em),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? RC.purple.withValues(alpha: 0.25) : RC.card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? RC.purple : RC.stroke),
                ),
                child: Text(em, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _FieldLabel(t('İsim', 'Name')),
        _input(_name, t('örn. Sabah meditasyonu', 'e.g. Morning meditation')),
        const SizedBox(height: 16),
        _FieldLabel(t('Kategori (isteğe bağlı)', 'Category (optional)')),
        _input(_category, t('örn. Zihin, Fitness', 'e.g. Mindfulness, Fitness')),
        const SizedBox(height: 18),
        _FieldLabel(t('Günler', 'Days')),
        Row(
          children: List.generate(7, (i) {
            final on = _days.contains(i);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (on) {
                      _days.remove(i);
                    } else {
                      _days.add(i);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: on ? RC.purple : RC.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: on ? RC.purple : RC.stroke),
                    ),
                    child: Text(_dow[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: on ? Colors.white : RC.muted)),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        RButton(editing ? t('Kaydet', 'Save') : t('Alışkanlık Ekle', 'Add Habit'),
            onTap: _save),
      ],
    );
  }
}

// ------------------------- EKLE / DÜZENLE: RECOVERY -------------------------

/// Recovery (streak) ekleme veya düzenleme alt sayfası.
Future<void> showRecoverySheet(BuildContext context, {Streak? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecoverySheet(existing: existing),
  );
}

class _RecoverySheet extends StatefulWidget {
  final Streak? existing;
  const _RecoverySheet({this.existing});
  @override
  State<_RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<_RecoverySheet> {
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _hours;
  late String _emoji;
  DateTime? _start;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _cost = TextEditingController(
        text: e != null && e.dailyCost > 0 ? e.dailyCost.toStringAsFixed(0) : '');
    _hours = TextEditingController(
        text: e != null && e.dailyHours > 0 ? e.dailyHours.toStringAsFixed(1) : '');
    _emoji = e?.emoji ?? '';
    _start = e?.start;
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _start = d);
  }

  void _save() {
    final s = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(t('Bir isim yaz 🙂', 'Type a name 🙂'));
      return;
    }
    final cost =
        double.tryParse(_cost.text.trim().replaceAll(',', '.')) ?? 0;
    final hours =
        double.tryParse(_hours.text.trim().replaceAll(',', '.')) ?? 0;
    if (widget.existing == null) {
      // NOT: Buradaki eski "ücretsiz sınıra ulaştın" engeli kaldırıldı —
      // bırakma takibi artık herkes için sınırsız (bkz. AppState.canAddStreak
      // ve ABONELIK-STRATEJISI.md). Bağımlılıklar kümelenir; üçüncü bir
      // bırakma hedefi eklemek isteyen kullanıcıyı duvara toslatmak, onu en
      // kırılgan anında cezalandırmaktı.
      s.addStreak(name,
          start: _start, dailyCost: cost, dailyHours: hours, emoji: _emoji);
    } else {
      s.editStreak(widget.existing!,
          name: name,
          start: _start,
          dailyCost: cost,
          dailyHours: hours,
          emoji: _emoji);
    }
    Navigator.pop(context);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final presets = addictionPresets();
    return _SheetScaffold(
      title: editing
          ? t('Kaydı Düzenle', 'Edit Recovery')
          : t('Yeni Bırakma Kaydı', 'New Recovery'),
      accent: RC.teal,
      children: [
        _FieldLabel(t('Hazır seçenekler', 'Quick picks')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((p) {
            final on = _name.text.trim().toLowerCase() == p.$2.toLowerCase();
            return GestureDetector(
              onTap: () => setState(() {
                if (on) {
                  // Zaten seçili olan bir hazır seçeneğe tekrar dokunmak onu
                  // kaldırır (isim/emoji temizlenir) — önceden seçiliyi
                  // kaldırmanın hiçbir yolu yoktu, elle silmek gerekiyordu.
                  _name.clear();
                  _emoji = '';
                } else {
                  _name.text = p.$2;
                  _emoji = p.$1;
                }
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? RC.teal.withValues(alpha: 0.18) : RC.card2,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: on ? RC.teal : RC.stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.$1, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(p.$2,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: on ? RC.teal : RC.text,
                            fontWeight:
                                on ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _FieldLabel(t('Neyi bırakıyorsun?', 'What are you quitting?')),
        _input(_name, t('örn. Sigara', 'e.g. Smoking'),
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(t('Günlük maliyet ₺', 'Daily cost')),
                  _input(_cost, t('örn. 90', 'e.g. 5'),
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(t('Günlük saat', 'Daily hours')),
                  _input(_hours, t('örn. 1.5', 'e.g. 1.5'),
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldLabel(t('Bırakma tarihi', 'Quit date')),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: RC.card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RC.stroke),
            ),
            child: Row(
              children: [
                Icon(Icons.event, size: 18, color: RC.teal),
                const SizedBox(width: 10),
                Text(
                    _start == null
                        ? t('Bugün (varsayılan)', 'Today (default)')
                        : '${_start!.day}.${_start!.month}.${_start!.year}',
                    style: TextStyle(color: RC.text)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        RButton(editing ? t('Kaydet', 'Save') : t('Başlat', 'Start'),
            onTap: _save, gradient: LinearGradient(colors: [RC.teal, RC.greenDeep])),
      ],
    );
  }
}

// ------------------------- SOS -------------------------

/// Acil destek: kriz/istek anında nefes + kazanımlar ekranını açar.
/// Birden çok kayıt varsa hangi alışkanlık için olduğunu sorar.
Future<void> openSos(BuildContext context) async {
  final s = context.read<AppState>();
  if (s.streaks.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(t('Önce bir bırakma kaydı ekle.',
              'Add a recovery first.'))));
    return;
  }
  Streak? target = s.streaks.length == 1 ? s.streaks.first : null;
  target ??= await showModalBottomSheet<Streak>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetScaffold(
        title: t('Hangisi için?', 'Which one?'),
        accent: RC.red,
        children: s.streaks
            .map((st) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RCard(
                    radius: 16,
                    onTap: () => Navigator.pop(context, st),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        EmojiTile(recoveryEmojiFor(st), tint: RC.tintTeal),
                        const SizedBox(width: 14),
                        // Expanded + ellipsis: Row içinde çıplak bir Text,
                        // kullanıcı uzun bir isim girdiğinde satırı taşırıp
                        // sarı-siyah overflow şeridine yol açıyordu.
                        Expanded(
                          child: Text(st.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  if (target != null && context.mounted) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CrisisScreen(streak: target!)));
  }
}

// ------------------------- ONAY DİYALOĞU -------------------------

/// Koyu arayüzle uyumlu onay diyaloğu. Onaylandıysa true döner.
Future<bool> rConfirm(BuildContext context,
    {required String title,
    required String message,
    required String confirmLabel,
    bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      backgroundColor: RC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: TextStyle(color: RC.text, fontSize: 18)),
      content: Text(message,
          style: TextStyle(color: RC.muted, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx, false),
          child: Text(t('Vazgeç', 'Cancel'),
              style: TextStyle(color: RC.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dCtx, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  color: danger ? RC.red : RC.purpleBright,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ------------------------- ORTAK ALT SAYFA KABI -------------------------

class _SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accent;
  const _SheetScaffold({required this.title, required this.children, this.accent});

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accent ?? RC.purple;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: RC.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: RC.stroke)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: RC.faint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(title,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: resolvedAccent)),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: TextStyle(
                color: RC.muted, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

Widget _input(TextEditingController c, String hint,
    {TextInputType? keyboard, ValueChanged<String>? onChanged}) {
  return TextField(
    controller: c,
    keyboardType: keyboard,
    onChanged: onChanged,
    style: TextStyle(color: RC.text),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: RC.muted),
      filled: true,
      fillColor: RC.card2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: RC.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: RC.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: RC.purple),
      ),
    ),
  );
}

// ------------------------- BAŞARIMLAR (ACHIEVEMENTS) -------------------------

class EarnedBadge {
  final String emoji, name, desc, rarity, category;
  final bool earned;
  const EarnedBadge(this.emoji, this.name, this.desc, this.rarity,
      this.category, this.earned);
}

bool _hasHabitNamed(AppState s, List<String> keys, int minStreak) {
  for (final task in s.tasks) {
    final n = task.name.toLowerCase();
    if (keys.any((k) => n.contains(k)) && s.taskStreak(task) >= minStreak) {
      return true;
    }
  }
  return false;
}

bool _hasRecoveryNamed(AppState s, List<String> keys, int minDays) {
  for (final st in s.streaks) {
    final n = st.name.toLowerCase();
    if (keys.any((k) => n.contains(k)) && st.days >= minDays) return true;
  }
  return false;
}

/// Gerçek kullanıcı verisine göre rozetlerin kazanılma durumunu değerlendirir.
///
/// Kazanılmayanlar da listeye girer: arayüz onları soluk gösterip hedef
/// olarak sunuyor.
///
/// (Yorum eskiden "12 rozet" diyordu; liste zamanla büyüdü ve sayı yanlış
/// kaldı. Sayı burada tekrar edilmiyor — kodda zaten görünüyor.)
List<EarnedBadge> evaluateBadges(AppState s) {
  final anyTaskDone = s.doneByDate.values.any((l) => l.isNotEmpty);
  final maxHabit = s.maxHabitStreak;
  final waterGoalDays =
      s.waterByDate.values.where((c) => c >= s.water.goal).length;
  final totalSaved = s.streaks.fold<double>(0, (a, b) => a + b.moneySaved);
  final anyRelapseComeback =
      s.streaks.any((st) => st.relapses > 0 || (st.bestDays > 0 && st.days < st.bestDays));
  final perfectWeek = s.checklistStreak >= 7;

  return [
    EarnedBadge('⭐', t('İlk Adım', 'First Step'),
        t('İlk alışkanlığını tamamla', 'Complete your first habit'),
        'COMMON', 'Habit', anyTaskDone),
    EarnedBadge('🔥', t('Hafta Savaşçısı', 'Week Warrior'),
        t('Herhangi bir alışkanlıkta 7 gün seri', '7-day streak on any habit'),
        'COMMON', 'Streak', maxHabit >= 7),
    EarnedBadge('🔒', t('Demir İrade', 'Iron Will'),
        t('Herhangi bir alışkanlıkta 30 gün seri', '30-day streak on any habit'),
        'RARE', 'Streak', maxHabit >= 30),
    EarnedBadge('💨', t('Dumansız', 'Smoke Free'),
        t('30 gün sigarasız', '30 days without smoking'),
        'RARE', 'Recovery',
        _hasRecoveryNamed(s, ['sigara', 'smok'], 30)),
    EarnedBadge('💧', t('Su Deposu', 'Hydrated'),
        t('10 gün su hedefini tuttur', '10 days hitting water goal'),
        'COMMON', 'Water', waterGoalDays >= 10),
    EarnedBadge('🌅', t('Erkenci', 'Early Bird'),
        t('Sabah 7\'den önce bir alışkanlık', 'Complete a habit before 7am'),
        'COMMON', 'Special', false),
    EarnedBadge('📚', t('Kitap Kurdu', 'Bookworm'),
        t('14 gün üst üste oku', 'Read for 14 days straight'),
        'RARE', 'Habit',
        _hasHabitNamed(s, ['oku', 'read', 'kitap', 'book'], 14)),
    EarnedBadge('💯', t('Yüzbaşı', 'Centurion'),
        t('Herhangi bir alışkanlıkta 100 gün seri', '100-day streak on any habit'),
        'EPIC', 'Streak',
        maxHabit >= 100 || s.streaks.any((st) => st.days >= 100)),
    EarnedBadge('🔄', t('Geri Dönüş', 'Comeback'),
        t('Bir nüksetmeden sonra yeniden başla', 'Restart after a relapse'),
        'COMMON', 'Recovery', anyRelapseComeback),
    EarnedBadge('🧘', t('Zen Ustası', 'Zen Master'),
        t('30 gün meditasyon', '30 days of meditation'),
        'EPIC', 'Habit',
        _hasHabitNamed(s, ['medit', 'zen', 'nefes'], 30)),
    EarnedBadge('💰', t('Kumbara', 'Money Saver'),
        t('Bırakarak 500\$ biriktir', 'Save \$500 in recovery'),
        'RARE', 'Recovery', totalSaved >= 500),
    EarnedBadge('🏆', t('Kusursuz Hafta', 'Perfect Week'),
        t('Bir hafta tüm alışkanlıklar tamam', 'All habits done for a week'),
        'EPIC', 'Special', perfectWeek),

    // ---- Ek rozetler ----
    // Hepsi GERÇEK veriden hesaplanır (uydurma/erişilemez rozet yok) ve
    // kolaydan zora bir merdiven oluşturur: kullanıcı her zaman "bir
    // sonraki"ni görebilmeli, aksi halde rozet sistemi motive etmez.
    EarnedBadge('🌱', t('Üç Gün', 'Three Days'),
        t('Herhangi bir alışkanlıkta 3 gün seri', '3-day streak on any habit'),
        'COMMON', 'Streak', maxHabit >= 3),
    EarnedBadge('🗓️', t('İki Hafta', 'Two Weeks'),
        t('Herhangi bir alışkanlıkta 14 gün seri', '14-day streak on any habit'),
        'COMMON', 'Streak', maxHabit >= 14),
    EarnedBadge('🎖️', t('Altmış Gün', 'Sixty Days'),
        t('Herhangi bir alışkanlıkta 60 gün seri', '60-day streak on any habit'),
        'EPIC', 'Streak', maxHabit >= 60),
    EarnedBadge('🧱', t('Sağlam Temel', 'Solid Base'),
        t('Aynı anda 3 alışkanlık takip et', 'Track 3 habits at once'),
        'COMMON', 'Habit', s.tasks.length >= 3),
    EarnedBadge('🎛️', t('Tam Program', 'Full Routine'),
        t('Aynı anda 5 alışkanlık takip et', 'Track 5 habits at once'),
        'RARE', 'Habit', s.tasks.length >= 5),
    EarnedBadge('🚰', t('Su Ustası', 'Water Master'),
        t('30 gün su hedefini tuttur', '30 days hitting water goal'),
        'RARE', 'Water', waterGoalDays >= 30),
    EarnedBadge('🌊', t('Akışta', 'In Flow'),
        t('100 gün su hedefini tuttur', '100 days hitting water goal'),
        'EPIC', 'Water', waterGoalDays >= 100),
    EarnedBadge('🪙', t('İlk Birikim', 'First Savings'),
        t('Bırakarak 100\$ biriktir', 'Save \$100 in recovery'),
        'COMMON', 'Recovery', totalSaved >= 100),
    EarnedBadge('💎', t('Servet', 'Fortune'),
        t('Bırakarak 2000\$ biriktir', 'Save \$2000 in recovery'),
        'EPIC', 'Recovery', totalSaved >= 2000),
    EarnedBadge('🌤️', t('İlk Hafta Temiz', 'First Clean Week'),
        t('Bir bırakmada 7 gün', '7 days on any recovery'),
        'COMMON', 'Recovery', s.streaks.any((st) => st.days >= 7)),
    EarnedBadge('🌗', t('Doksan Gün', 'Ninety Days'),
        t('Bir bırakmada 90 gün', '90 days on any recovery'),
        'EPIC', 'Recovery', s.streaks.any((st) => st.days >= 90)),
    EarnedBadge('🎯', t('Çift Yol', 'Two Fronts'),
        t('Aynı anda 2 şey bırak', 'Quit 2 things at once'),
        'RARE', 'Recovery', s.streaks.length >= 2),
    EarnedBadge('📆', t('Üç Kusursuz Hafta', 'Three Perfect Weeks'),
        t('21 gün üst üste listeyi bitir', 'Finish your list 21 days straight'),
        'EPIC', 'Special', s.checklistStreak >= 21),
    EarnedBadge('👥', t('Yalnız Değilsin', 'Not Alone'),
        t('Bir sorumluluk ortağı ekle', 'Add an accountability partner'),
        'COMMON', 'Special', s.acceptedFriends.isNotEmpty),
    EarnedBadge('✍️', t('Kendine Söz', 'Word to Yourself'),
        t('Geleceğe mektup yaz', 'Write a letter to your future self'),
        'COMMON', 'Special', s.streaks.any((st) => st.letter.isNotEmpty)),
    EarnedBadge('🛡️', t('Dalgayı Aştın', 'Rode the Wave'),
        t('Bir krizi atlat', 'Ride out a craving'),
        'COMMON', 'Recovery', s.triggerLog.any((e) => e.survived)),
    EarnedBadge('⚓', t('Sarsılmaz', 'Unshaken'),
        t('10 krizi atlat', 'Ride out 10 cravings'),
        'EPIC', 'Recovery',
        s.triggerLog.where((e) => e.survived).length >= 10),
  ];
}