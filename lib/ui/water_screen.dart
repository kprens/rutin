import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../store.dart';
import 'rutin_ui.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});
  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final _ctrl = TextEditingController();
  static const cupMl = 250;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cups = s.water.count;
    final goal = s.water.goal;
    final log = s.todaysWaterLog;

    // ÖNEMLİ: Litre/kalan miktar HER ZAMAN gerçek loglanan ml toplamından
    // (s.todaysWaterMl) hesaplanır — yuvarlanmış "bardak" sayısından değil.
    // Önceki haliyle burada `cups * cupMl` kullanılıyordu; kullanıcı 150ml,
    // 300ml gibi 250'nin katı olmayan miktarlar eklediğinde (Hızlı Ekle veya
    // Özel miktar) yuvarlama yüzünden üstteki toplam, alttaki "Bugünün
    // Kaydı" listesindeki gerçek toplamla ÖRTÜŞMÜYORDU (ör. 450ml log
    // toplamı varken üstte "0.50L" görünüyordu) — kullanıcıların "matematik
    // hatası" olarak bildirdiği sorun buydu.
    final mlTotal = s.todaysWaterMl;
    final goalMl = goal * cupMl;
    final liters = mlTotal / 1000;
    final goalL = goalMl / 1000;
    final ratio = goalMl == 0 ? 0.0 : (mlTotal / goalMl).clamp(0.0, 1.0);
    final remaining = (goalMl - mlTotal).clamp(0, goalMl);
    final cupsToGo = (goal - cups).clamp(0, goal);

    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              rutinAppBar(context, t('Su Takibi', 'Water Tracker')),
              const SizedBox(height: 20),

              // ---- Büyük ilerleme kartı ----
              RCard(
                color: RC.tintBlue,
                border: RC.blue.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: [
                    Icon(Icons.water_drop_rounded, size: 48, color: RC.blue),
                    const SizedBox(height: 12),
                    Text('${liters.toStringAsFixed(2)}L',
                        style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: RC.blue)),
                    Text(
                        t('${goalL.toStringAsFixed(1)}L günlük hedeften',
                            'of ${goalL.toStringAsFixed(1)}L daily goal'),
                        style: TextStyle(color: RC.muted, fontSize: 15)),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: RC.card2,
                        valueColor: AlwaysStoppedAnimation(RC.blue),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                        remaining <= 0
                            ? t('Hedef tamam! 🎉', 'Goal reached! 🎉')
                            : t('${remaining}ml kaldı — $cupsToGo bardak',
                                '${remaining}ml remaining — $cupsToGo cups to go'),
                        style: TextStyle(color: RC.muted, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ..._cupsAndGoal(s, cups: cups, goal: goal),
              const SizedBox(height: 22),

              Text(t('Hızlı Ekle', 'Quick Add'), style: RText.title),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final ml in [150, 250, 300, 500]) ...[
                    Expanded(child: _quickAdd(s, ml)),
                    if (ml != 500) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ---- Özel miktar ----
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: RC.text),
                      decoration: InputDecoration(
                        hintText: t('Özel miktar (ml)', 'Custom amount (ml)'),
                        hintStyle: TextStyle(color: RC.muted),
                        filled: true,
                        fillColor: RC.card2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: RC.stroke),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: RC.stroke),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final v = int.tryParse(_ctrl.text) ?? 0;
                      if (v > 0) s.addWaterMl(v);
                      _ctrl.clear();
                    },
                    child: Container(
                      height: 54,
                      width: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: RG.blueBtn,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: RC.blue.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Text(t('Ekle', 'Add'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(t("Bugünün Kaydı", "Today's Log"), style: RText.title),
              const SizedBox(height: 12),
              if (log.isEmpty)
                REmpty(
                  compact: true,
                  icon: Icons.water_drop_outlined,
                  title: t('Henüz su eklemedin', 'No water logged yet'),
                  message: t('Yukarıdaki butonlarla ilk kaydını ekle.',
                      'Use the buttons above to add your first entry.'),
                )
              else
                ...log.map((e) => Padding(
                      key: ValueKey('${e.time}-${e.ml}-${e.hashCode}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RCard(
                        radius: 16,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.water_drop_rounded, size: 18, color: RC.blue),
                            const SizedBox(width: 12),
                            Text('${e.ml}ml',
                                style: TextStyle(
                                    color: RC.blue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            const Spacer(),
                            Text(e.time,
                                style: TextStyle(
                                    color: RC.muted, fontSize: 14)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => s.removeWaterLog(e),
                              child: Icon(Icons.close,
                                  size: 18, color: RC.muted),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }


  /// Bugünün bardak sırası ve günlük hedef ayarı.
  ///
  /// Widget DEĞİL, liste döndürüyor: bunlar ListView'in doğrudan çocukları
  /// ve ListView çocuklarını yatayda GERER. Araya bir Column konursa
  /// varsayılan hizalaması (center) devreye girer ve kart genişliğini
  /// kaybederdi.
  List<Widget> _cupsAndGoal(AppState s,
          {required int cups, required int goal}) =>
      [
          RCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(t('Bugün', 'Today'),
                    style: TextStyle(color: RC.muted, fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < goal; i++)
                        Container(
                          width: 20,
                          height: 30,
                          decoration: BoxDecoration(
                            color: i < cups ? RC.blue : RC.card2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: RC.stroke),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('$cups/$goal',
                    style: TextStyle(
                        color: RC.blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Hedef +/- (gerçek changeGoal)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _goalBtn(Icons.remove, () => s.changeGoal(-1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    t('Günlük hedef: $goal bardak', 'Daily goal: $goal cups'),
                    style: TextStyle(color: RC.muted, fontSize: 13)),
              ),
              _goalBtn(Icons.add, () => s.changeGoal(1)),
            ],
          ),
      ];

  Widget _goalBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RC.card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RC.stroke),
          ),
          child: Icon(icon, color: RC.blue, size: 20),
        ),
      );

  Widget _quickAdd(AppState s, int ml) => GestureDetector(
        onTap: () => s.addWaterMl(ml),
        child: RCard(
          key: ValueKey('quickAdd_$ml'),
          color: RC.tintBlue,
          border: RC.blue.withValues(alpha: 0.2),
          radius: 16,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(Icons.water_drop_rounded, size: 22, color: RC.blue),
              const SizedBox(height: 10),
              Text('${ml}ml',
                  style: TextStyle(
                      color: RC.blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
        ),
      );
}

/// Alt ekranlarda kullanılan geri butonlu başlık.
