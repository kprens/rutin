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

import '../l10n.dart';

import '../theme.dart';

/// ------------------------- RENK PALETİ -------------------------
/// Not: Bu değerler artık sabit değil — kullanıcının Tema ekranından
/// seçtiği `currentTheme` (theme.dart) ve Ayarlar'daki Koyu Mod tercihine
/// (`useDarkPalette`) göre HER ÇAĞRIDA taze okunuyor. Böylece hem tema
/// hem açık/koyu mod değişimi bu sistemi kullanan ekranlara (Settings,
/// Home, vb.) da yansır.
class RC {
  RC._();

  static RutinColors get _p =>
      useDarkPalette ? currentTheme.dark : currentTheme.light;

  // Zeminler
  static Color get bg => _p.bg; // ana arka plan
  static Color get bgTop =>
      Color.alphaBlend(_p.accent.withValues(alpha: 0.10), _p.bg); // başlık üstü gradyan
  static Color get card => _p.card; // standart kart
  static Color get card2 => _p.card2; // iç kart / input
  static Color get stroke => _p.cardBorder; // kart kenarı
  static Color get strokeSoft =>
      stroke.withValues(alpha: stroke.a * 0.5); // daha hafif kenar

  // Metin
  static Color get text => _p.text;
  static Color get muted => _p.muted;
  /// Üçüncü metin kademesi.
  ///
  /// Eskiden `muted`'in %45 saydamlıkla açılmış haliydi ve ölçülen kontrast
  /// **1.55–2.32:1** idi — WCAG AA'nın (4.5:1) çok altında, 20 tema/mod
  /// kombinasyonunun HEPSİNDE. Dekoratif bir renk olsa sorun olmazdı ama
  /// gerçek metinde kullanılıyordu: en kritiği paywall'daki deneme süresi /
  /// fiyat / otomatik yenileme beyanı (11px). Okunamayan bir beyan, beyan
  /// değildir — bu hem erişilebilirlik hem de mağaza uyumluluğu sorunuydu.
  ///
  /// Ölçüm şunu gösterdi: bu yazı boyutlarında (11–13px) `muted`'ten DAHA
  /// AÇIK bir kademe AA'yı geçemiyor — saydamlık 1.0 olsa bile sınırda
  /// kalıyor. Yani üçüncü kademe matematiksel olarak mümkün değil; `faint`
  /// artık `muted` ile aynı. Görsel hiyerarşi renk yerine yazı boyutu ve
  /// ağırlığıyla kurulmalı.
  static Color get faint => _p.muted;

  // Aksanlar
  static Color get purple => _p.accent; // birincil
  static Color get purpleBright => _p.accent2; // parlama / vurgu
  static Color get teal => _p.blue; // recovery / temiz gün
  static Color get blue => _p.blue; // su
  static Color get amber => _p.amber; // streak / best day
  static Color get green => _p.green; // takvim "hepsi bitti"
  static Color get greenDeep =>
      Color.alphaBlend(_p.green.withValues(alpha: 0.55), _p.bg);
  static Color get pink =>
      Color.lerp(_p.red, _p.accent2, 0.5)!; // active streaks metrik
  static Color get red => _p.red; // sil / çıkış

  // Kart tint'leri (analytics kartları)
  static Color get tintPurple =>
      Color.alphaBlend(purple.withValues(alpha: 0.14), _p.bg);
  static Color get tintAmber =>
      Color.alphaBlend(amber.withValues(alpha: 0.14), _p.bg);
  static Color get tintGreen =>
      Color.alphaBlend(green.withValues(alpha: 0.14), _p.bg);
  static Color get tintPink =>
      Color.alphaBlend(pink.withValues(alpha: 0.14), _p.bg);
  static Color get tintTeal =>
      Color.alphaBlend(teal.withValues(alpha: 0.14), _p.bg);
  static Color get tintBlue =>
      Color.alphaBlend(blue.withValues(alpha: 0.14), _p.bg);
}

/// Sık kullanılan gradyanlar — bunlar da artık seçili temaya göre üretiliyor.
class RG {
  RG._();
  static LinearGradient get purpleBtn => LinearGradient(
        colors: [RC.purple, RC.purpleBright],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get blueBtn => LinearGradient(
        colors: [RC.blue, RC.purpleBright],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get header => LinearGradient(
        colors: [RC.bgTop, RC.bg],
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
    colorScheme: ColorScheme.dark(
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
  static TextStyle get h1 => TextStyle(
      fontSize: 34, fontWeight: FontWeight.w800, color: RC.text, height: 1.05);
  static TextStyle get h2 => TextStyle(
      fontSize: 26, fontWeight: FontWeight.w800, color: RC.text, height: 1.1);
  static TextStyle get title => TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, color: RC.text);
  static TextStyle get body =>
      TextStyle(fontSize: 15, color: RC.text, height: 1.35);
  static TextStyle get muted =>
      TextStyle(fontSize: 14, color: RC.muted, height: 1.4);
  static TextStyle get label => TextStyle(
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
  final Color? color;
  final Color track;
  final Widget? center;
  final bool rounded;
  final double startAngle; // radyan

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 10,
    this.color,
    this.track = const Color(0x1AFFFFFF),
    this.center,
    this.rounded = true,
    this.startAngle = -math.pi / 2,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? RC.purple;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(value, stroke, ringColor, track, rounded, startAngle),
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
  final Color? tint;
  final double size;
  final double radius;
  const EmojiTile(this.emoji,
      {super.key, this.tint, this.size = 48, this.radius = 14});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tint ?? RC.card2,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: RC.stroke),
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.44)),
      );
}

/// [EmojiTile] ile aynı görünüm, ama sabit/dekoratif (kullanıcı seçimi
/// olmayan) menü/simge kutuları için emoji yerine gerçek bir [Icon]
/// kullanır — ör. profil menüsündeki "Başarımlar", "Ayarlar" satırları.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? tint;
  final Color? iconColor;
  final double size;
  final double radius;
  const IconTile(this.icon,
      {super.key, this.tint, this.iconColor, this.size = 48, this.radius = 14});
  @override
  // ExcludeSemantics: bu kutu tanımı gereği DEKORATİF (sınıf açıklamasına
  // bakınız) — yanındaki metin zaten anlamı taşıyor. Dışlanmazsa ekran
  // okuyucu her satırda önce anlamsız bir ikon düğümü okur ve listede
  // gezinmek iki kat uzun sürer.
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint ?? RC.card2,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: RC.stroke),
          ),
          child: Icon(icon, size: size * 0.5, color: iconColor ?? RC.text),
        ),
      );
}

/// Degrade birincil buton (Continue, Create Account, Add...).
class RButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double height;
  final Widget? leading;
  const RButton(this.label,
      {super.key,
      this.onTap,
      this.gradient,
      this.height = 52, // önceden 58 — genel geri bildirim üzerine biraz küçültüldü
      this.leading});
  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? RG.purpleBtn;
    // ERİŞİLEBİLİRLİK: GestureDetector hiçbir semantik bilgi üretmez — ekran
    // okuyucu yalnızca metni okur, bunun BİR BUTON olduğunu ve dokunulabilir
    // olup olmadığını söylemez. `button: true` VoiceOver/TalkBack'e "düğme"
    // dedirtir; `enabled` ise onTap null iken "devre dışı" bilgisini verir.
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      // Metin zaten label olarak verildi; alttaki Text'in ayrıca okunması
      // etiketin iki kez seslendirilmesine yol açardı.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
        alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: grad.colors.first.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(
                // Dinamik yazı boyutu büyütüldüğünde (Ayarlar → Erişilebilirlik
                // → Daha Büyük Metin) etiket sabit yükseklikli butonu taşırıp
                // sarı-siyah "overflow" şeridine yol açıyordu. Flexible +
                // ellipsis, buton düzenini bozmadan metni sığdırır.
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
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
    // ERİŞİLEBİLİRLİK — üç ayrı sorun vardı:
    //
    // 1. Semantik yok: ekran okuyucu bunun bir anahtar olduğunu da, açık mı
    //    kapalı mı olduğunu da söyleyemiyordu. Ayarlar ekranı tamamen bu
    //    bileşenden oluştuğu için görme engelli bir kullanıcı hiçbir ayarı
    //    yönetemezdi.
    // 2. Dokunma hedefi 52x30'du; hem iOS (44pt) hem Android (48dp) minimumun
    //    altında. Görsel boyut korunuyor, dokunulabilir alan büyütülüyor.
    // 3. Durum YALNIZCA renkle anlatılıyordu (mor/gri). Renk körlüğünde iki
    //    durum ayırt edilemiyordu; artık topuz konumu da (sola/sağa) bilgi
    //    taşıyor — zaten öyleydi, semantik etiketle birlikte artık
    //    seslendiriliyor da.
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: () => onChanged?.call(!value),
        // opaque: yalnızca boyanan piksellerin değil, tüm 48dp'lik alanın
        // dokunmayı yakalaması için.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          width: 52,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(3),
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                // Kapalı durum rengi eskiden sabit `0xFF2A2D3A` idi — koyu
                // lacivert bir ton. Koyu temada doğru görünüyordu ama AÇIK
                // temada beyaz kartın üstünde neredeyse siyah bir leke gibi
                // duruyordu ve tema seçiminden bağımsızdı. Artık paletten
                // geliyor.
                color: value ? RC.purple : RC.strokeSoft,
                borderRadius: BorderRadius.circular(99),
                boxShadow: value
                    ? [
                        BoxShadow(
                            color: RC.purple.withValues(alpha: 0.5),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    // Kapalıyken topuz açık zemin üzerinde beyaz kalıyordu ve
                    // kaybolabiliyordu; ince kenarlık onu her durumda
                    // görünür kılar.
                    border: Border.all(color: RC.stroke)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standart BOŞ DURUM.
///
/// Boş durumlar uygulamanın en çok ihmal edilen ekranlarıdır, oysa yeni
/// kullanıcının ilk gördüğü şey tam olarak budur. Önceden her ekran bunu
/// kendi başına çözüyordu: çoğu yerde tek satır gri metin, bazı yerlerde
/// hiçbir şey. İki sorunu vardı — görsel olarak "bozuk/eksik" hissi
/// veriyordu ve kullanıcıya NE YAPACAĞINI söylemiyordu.
///
/// Buradaki kurgu üç parçalı: ikon (ekranın boş değil, kasıtlı olduğunu
/// gösterir), başlık + açıklama (ne olduğu ve neden), ve isteğe bağlı bir
/// eylem butonu. Boş durum bir hata değil, bir davettir.
class REmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  /// Eylem butonu — varsa kullanıcı ekrandan çıkmadan devam edebilir.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Dar alanlarda (kart içi) daha küçük bir varyant.
  final bool compact;

  const REmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return RCard(
      color: RC.card,
      border: RC.strokeSoft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dekoratif: anlamı alttaki başlık taşıyor, ekran okuyucunun
            // ayrıca bir ikon düğümü okumasına gerek yok.
            ExcludeSemantics(
              child: Container(
                width: compact ? 44 : 60,
                height: compact ? 44 : 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RC.card2,
                  shape: BoxShape.circle,
                  border: Border.all(color: RC.stroke),
                ),
                child: Icon(icon,
                    size: compact ? 22 : 28, color: RC.muted),
              ),
            ),
            SizedBox(height: compact ? 10 : 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RC.text,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: RC.muted,
                      fontSize: compact ? 12.5 : 13.5,
                      height: 1.45)),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 12 : 18),
              RButton(actionLabel!, onTap: onAction, height: 44),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standart HATA DURUMU — yeniden deneme imkânıyla.
///
/// "Bir şeyler ters gitti" deyip bırakmak kullanıcıyı çıkmaza sokar; her hata
/// ekranı bir çıkış yolu sunmalı.
class RError extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const RError({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => REmpty(
        icon: Icons.cloud_off_rounded,
        title: title,
        message: message,
        actionLabel: onRetry == null ? null : t('Tekrar Dene', 'Try Again'),
        onAction: onRetry,
      );
}

/// VERİYE ULAŞILAMIYOR uyarısı.
///
/// NEDEN AYRI BİR BİLEŞEN: Yükleme başarısız olduğunda ekranda görünen
/// boşluk, kullanıcı açısından "veri yok"tan ayırt edilemez. 200 günlük
/// serisi olan biri uygulamayı açıp boş ekran görürse verisinin silindiğini
/// düşünür — bu, kategorideki en sık 1 yıldız sebebidir ve kullanıcı
/// genellikle uygulamayı silerek "çözer".
///
/// Bu şerit tam olarak şunu söyler: veri duruyor, sorun geçici, şu an
/// yazdıkların kaybolmayacak. Mesajın tonu bilinçli olarak sakinleştirici.
class DataUnavailableBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  const DataUnavailableBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RCard(
        color: Color.alphaBlend(RC.amber.withValues(alpha: 0.12), RC.card),
        border: RC.amber.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.cloud_off_rounded,
                  size: 20, color: RC.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      t('Verilerine şu an ulaşılamıyor',
                          "Can't reach your data right now"),
                      style: TextStyle(
                          color: RC.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                      t('Verilerin silinmedi — bağlantı kurulunca geri gelecek. Bu sırada yaptığın değişiklikler cihazında saklanıyor.',
                          "Your data isn't lost — it'll come back once you're connected. Changes you make now are saved on your device."),
                      style: TextStyle(
                          color: RC.muted, fontSize: 12.5, height: 1.45)),
                  if (onRetry != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onRetry,
                      child: Semantics(
                        button: true,
                        label: t('Tekrar dene', 'Try again'),
                        excludeSemantics: true,
                        child: Container(
                          // 44dp: dokunma hedefi minimumu.
                          height: 44,
                          alignment: Alignment.centerLeft,
                          child: Text(t('Tekrar dene', 'Try again'),
                              style: TextStyle(
                                  color: RC.purpleBright,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt ekranların standart başlık çubuğu: geri butonu + başlık.
///
/// Burada duruyor çünkü PAYLAŞILAN bir bileşen. Önceden
/// `water_screen.dart`'ta tanımlıydı ve 8 ekran (paywall, ayarlar,
/// arkadaşlar, rozetler, haftalık rapor, içgörüler, mektup, iyileşme
/// zaman çizelgesi) yalnızca bunu alabilmek için su takip ekranını import
/// ediyordu — yani satın alma ekranı, su ekranının tüm bağımlılıklarını
/// sürüklüyordu. Paylaşılan UI'nin yeri UI kit'tir.
///
/// Geri butonu 48×48: dokunma hedefi minimumunun üstünde.
Widget rutinAppBar(BuildContext context, String title) => Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RC.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RC.stroke),
            ),
            child: Icon(Icons.chevron_left, color: RC.text),
          ),
        ),
        const SizedBox(width: 14),
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ],
    );

/// Ekran içeriği için standart kaydırılabilir gövde (üstte hafif gradyan).
/// Geniş ekranlarda (iPad) içeriğin uzayabileceği azami genişlik.
///
/// App Store, telefon için tasarlanmış ekranların iPad'de 820pt'ye yayılmasını
/// Guideline 4 altında düşük kaliteli deneyim sayıp uygulamayı reddetmişti.
const double kMaxContentWidth = 560;

/// Kaydırma alanının kendi dolgusunu, içeriği [kMaxContentWidth] genişliğinde
/// ORTALAYACAK şekilde büyütür.
///
/// NEDEN DOLGU, NEDEN SARMALAYICI DEĞİL — bu ayrım bir App Store reddine mal
/// oldu (Guideline 2.1(a), "the app became unresponsive when tapping
/// anywhere"):
///
/// Sınır önce `MaterialApp.builder` içinde, Navigator'ı `Center` +
/// `ConstrainedBox` ile sararak uygulanıyordu. Görsel sonuç doğruydu ama
/// Navigator'ın İÇİNDEKİ her şey de daralıyordu — sayfa geçişleri, diyaloglar
/// ve en önemlisi MODAL PERDELER. iPad'de bir alt sayfa açıp kapatmak için
/// dışına dokunan kullanıcı hiçbir şeye dokunmuş olmuyordu: perde ekranın
/// yalnızca orta 560pt'sini kaplıyor, kalan ~130pt'lik (yatayda ~310pt)
/// kenarlar tamamen ölüydü. Uygulama donmuş gibi görünüyordu.
///
/// Dolgu yaklaşımında kaydırma alanı TAM GENİŞLİKTE kalır — her yerden
/// kaydırılır, her yere dokunulur — yalnızca içerik ortalanır. Navigator'a
/// hiç dokunulmadığı için perdeler yine tüm ekranı kaplar.
EdgeInsets rContentPadding(BuildContext context, EdgeInsets base) {
  final extra =
      ((MediaQuery.sizeOf(context).width - kMaxContentWidth) / 2)
          .clamp(0.0, double.infinity);
  return base.copyWith(left: base.left + extra, right: base.right + extra);
}

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
      // Dolgu geniş ekranda büyür; ListView tam genişlikte kalır.
      child: ListView(
          padding: rContentPadding(context, padding), children: children),
    );
  }
}