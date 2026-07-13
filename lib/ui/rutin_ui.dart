/// Rutin — yeni koyu arayüz tasarım sistemi.
///
/// Screenshot'lara birebir uyacak şekilde: koyu arka plan, mor + teal
/// aksanlar, gradyan kartlar, yuvarlak köşeler. Tek dosyada tasarım
/// token'ları (renkler, tipografi), ortak widget'lar ve örnek veri.
///
/// Not: Screenshot'lardaki yuvarlak tipografi için pubspec'e Poppins
/// (veya benzeri) ekleyip `fontFamily`'yi RUI.textTheme'de açabilirsin.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ------------------------- RENK PALETİ -------------------------
class RC {
  RC._();

  // Zeminler
  static const bg = Color(0xFF07080D); // ana arka plan (neredeyse siyah)
  static const bgTop = Color(0xFF141428); // başlıklardaki üst gradyan
  static const card = Color(0xFF12141C); // standart kart
  static const card2 = Color(0xFF171923); // iç kart / input
  static const stroke = Color(0x14FFFFFF); // kart kenarı (beyaz %8)
  static const strokeSoft = Color(0x0DFFFFFF); // daha hafif kenar

  // Metin
  static const text = Color(0xFFF3F4FA);
  static const muted = Color(0xFF8A8FA3);
  static const faint = Color(0xFF4C5064);

  // Aksanlar
  static const purple = Color(0xFF7C6BF0); // birincil
  static const purpleBright = Color(0xFF9B8CFF); // parlama / vurgu
  static const teal = Color(0xFF4FD6BB); // recovery / temiz gün
  static const blue = Color(0xFF5BB4F2); // su
  static const amber = Color(0xFFF3B54A); // streak / best day
  static const green = Color(0xFF5FBE85); // takvim "hepsi bitti"
  static const greenDeep = Color(0xFF2E6B47);
  static const pink = Color(0xFFE86A86); // active streaks metrik
  static const red = Color(0xFFF0655F); // sil / çıkış

  // Kart tint'leri (analytics kartları)
  static const tintPurple = Color(0xFF171634);
  static const tintAmber = Color(0xFF2A2413);
  static const tintGreen = Color(0xFF10261A);
  static const tintPink = Color(0xFF2A1620);
  static const tintTeal = Color(0xFF0E2622);
  static const tintBlue = Color(0xFF0E1E2C);
}

/// Sık kullanılan gradyanlar.
class RG {
  RG._();
  static const purpleBtn = LinearGradient(
    colors: [Color(0xFF8B78F5), Color(0xFF6C5AE0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const blueBtn = LinearGradient(
    colors: [Color(0xFF74C3F7), Color(0xFF4BA3EC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient header = const LinearGradient(
    colors: [Color(0xFF16172B), Color(0xFF07080D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// ------------------------- TEMA -------------------------
ThemeData buildRutinDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RC.bg,
    colorScheme: const ColorScheme.dark(
      surface: RC.bg,
      primary: RC.purple,
      secondary: RC.teal,
    ),
    // Poppins eklersen: fontFamily: 'Poppins',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: RC.text, displayColor: RC.text),
    splashFactory: InkRipple.splashFactory,
  );
}

/// ------------------------- METİN STİLLERİ -------------------------
class RText {
  RText._();
  static const h1 = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w800, color: RC.text, height: 1.05);
  static const h2 = TextStyle(
      fontSize: 26, fontWeight: FontWeight.w800, color: RC.text, height: 1.1);
  static const title = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, color: RC.text);
  static const body = TextStyle(fontSize: 15, color: RC.text, height: 1.35);
  static const muted = TextStyle(fontSize: 14, color: RC.muted, height: 1.4);
  static const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: RC.muted);
}

/// ------------------------- ORTAK WIDGET'LAR -------------------------

/// Standart kart kabı — isteğe bağlı gradyan/tint ve kenar rengi.
class RCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? border;
  final double radius;
  final VoidCallback? onTap;

  const RCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.gradient,
    this.border,
    this.radius = 22,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? RC.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? RC.stroke),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Bölüm başlığı — büyük harf, aralıklı (NOTIFICATIONS, ACCOUNT...).
class RLabel extends StatelessWidget {
  final String text;
  const RLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
        child: Text(text.toUpperCase(), style: RText.label),
      );
}

/// Dairesel ilerleme halkası (Home %60, Recovery, Profile...).
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? center;
  final bool rounded;
  final double startAngle; // radyan

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 10,
    this.color = RC.purple,
    this.track = const Color(0x1AFFFFFF),
    this.center,
    this.rounded = true,
    this.startAngle = -math.pi / 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(value, stroke, color, track, rounded, startAngle),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value, stroke, startAngle;
  final Color color, track;
  final bool rounded;
  _RingPainter(this.value, this.stroke, this.color, this.track, this.rounded,
      this.startAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..strokeCap = rounded ? StrokeCap.round : StrokeCap.butt;
    canvas.drawCircle(center, radius, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = rounded ? StrokeCap.round : StrokeCap.butt
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi,
        colors: [color, color.withValues(alpha: 0.85)],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        2 * math.pi * value.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

/// Emoji ikon kutusu (habit / recovery avatarları).
class EmojiTile extends StatelessWidget {
  final String emoji;
  final Color tint;
  final double size;
  final double radius;
  const EmojiTile(this.emoji,
      {super.key, this.tint = RC.card2, this.size = 48, this.radius = 14});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: RC.stroke),
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.44)),
      );
}

/// Degrade birincil buton (Continue, Create Account, Add...).
class RButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Gradient gradient;
  final double height;
  final Widget? leading;
  const RButton(this.label,
      {super.key,
      this.onTap,
      this.gradient = RG.purpleBtn,
      this.height = 58,
      this.leading});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(label,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// iOS tarzı toggle (Settings).
class RSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const RSwitch({super.key, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? RC.purple : const Color(0xFF2A2D3A),
          borderRadius: BorderRadius.circular(99),
          boxShadow: value
              ? [BoxShadow(color: RC.purple.withValues(alpha: 0.5), blurRadius: 12)]
              : null,
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Ekran içeriği için standart kaydırılabilir gövde (üstte hafif gradyan).
class RScreen extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const RScreen(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 40)});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: RG.header),
      child: ListView(padding: padding, children: children),
    );
  }
}
