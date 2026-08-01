import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../ads.dart';
import '../analytics.dart';
import '../iap.dart';
import '../l10n.dart';
import '../legal.dart';
import '../store.dart';
import 'rutin_ui.dart';

/// Mağazadan GELEN ürünlere göre gösterilecek planları ve geçerli seçimi
/// belirler. Saf fonksiyon — UI'ya, platforma ve ağa bağlı değil.
///
/// NEDEN AYRI: Eskiden bu karar `build()` içinde satır içindeydi ve koşul
/// `yearly != null && monthly != null` idi — yani İKİSİ birden gerekiyordu.
/// Tek bir ürün mağazadan gelmediğinde paywall TAMAMEN kapanıyordu; yıllık
/// plan sorunsuz gelse bile kullanıcı hiçbir şey satın alamıyordu. App Store
/// bunu "an error is shown when trying to access the in-app purchases"
/// diyerek 2.1(b) altında reddetti.
///
/// UI içinde kaldığı sürece bu davranışın testi de yazılamıyordu; buraya
/// taşınması onu doğrulanabilir kıldı.
@visibleForTesting
({List<String> plans, String selected}) resolvePaywallPlans({
  required bool hasYearly,
  required bool hasMonthly,
  required String currentSelection,
}) {
  final plans = <String>[
    if (hasYearly) Iap.yearlyId,
    if (hasMonthly) Iap.monthlyId,
  ];
  // Seçili plan gelmediyse seçimi gelen ilk plana taşı: aksi halde hiçbir
  // kart seçili görünmez ve satın alma butonu var olmayan bir ürünü hedefler.
  final selected = plans.isEmpty || plans.contains(currentSelection)
      ? currentSelection
      : plans.first;
  return (plans: plans, selected: selected);
}

/// Yıllık planda App Store Connect'te tanımlı bir ÜCRETSİZ DENEME
/// (Introductory Offer) var mı.
///
/// VARSAYILAN `false` — bilinçli ve güvenli taraf.
///
/// Paywall eskiden koşulsuz olarak "7 Gün Ücretsiz Dene" yazıyordu. App
/// Store Connect'te böyle bir teklif tanımlı DEĞİLSE kullanıcı butona basıp
/// anında ücretlendirilir: Guideline 2.3 (yanıltıcı beyan) ihlali, iade ve
/// düşük puan sebebi. Denetim sırasında yıllık abonelik sayfasında
/// "Introductory Offers" bölümü görülemedi, yani teklifin varlığı
/// KANITLANAMADI.
///
/// Asimetri tek yönlü: deneme yokken vaat etmek zararlı; varken vaat
/// etmemek yalnızca küçük bir dönüşüm kaybı — üstelik Apple'ın satın alma
/// ekranı teklifi zaten kendisi gösterir.
///
/// NASIL AÇILIR: App Store Connect → Subscriptions → Rutin Pro Yıllık →
/// Introductory Offers bölümünde 1 haftalık ücretsiz teklifin tanımlı
/// olduğu DOĞRULANDIKTAN sonra burayı `true` yap. Başka hiçbir yeri
/// değiştirmek gerekmez.
///
/// (Kalıcı çözüm, teklifi çalışma zamanında mağazadan okumaktır —
/// `in_app_purchase_storekit` gerektirir, 1.0.1'e bırakıldı.)
const bool kYearlyHasIntroTrial = false;

class PaywallScreen extends StatefulWidget {
  /// Paywall'ın NEREDEN açıldığı — ölçümün en değerli tek parametresi.
  ///
  /// Hangi giriş noktasının gerçekten satışa dönüştüğünü (ana ekran kartı mı,
  /// kilitli tema mı, haftalık rapor mu) bilmeden paywall'ı iyileştirmek
  /// körlemesine denemektir. Yeni bir giriş noktası eklerken buraya kısa,
  /// boşluksuz bir kaynak adı geçir.
  final String source;

  const PaywallScreen({super.key, this.source = 'unknown'});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  /// Varsayılan seçili plan: YILLIK.
  ///
  /// Bu bilinçli bir karar. Yıllık plan hem kullanıcı için aylıktan çok daha
  /// ucuz (aylık maliyeti ~%60 düşük) hem de iş için çok daha değerli
  /// (peşin nakit, düşük iptal, yüksek LTV). Bu kategoride abonelik
  /// gelirinin büyük çoğunluğu yıllık plandan gelir. Önceki sürümde yıllık
  /// ürün (Iap.yearlyId) tanımlı ve mağazadan çekiliyor olmasına rağmen bu
  /// ekranda HİÇ GÖSTERİLMİYORDU — yani satın alınması imkânsızdı.
  String _selectedId = Iap.yearlyId;

  /// Satın alma başlatıldı mı — vazgeçme (dismiss) olayını doğru
  /// sınıflandırmak için. Satın alan kullanıcının çıkışı "vazgeçti" değildir.
  bool _purchaseAttempted = false;

  @override
  void initState() {
    super.initState();
    Analytics.instance
        .log(Ev.paywallView, {'source': widget.source, 'plan': _selectedId});
    // Boot sırasında mağaza katmanı yüklenememişse (Billing yanıt vermedi /
    // zaman aşımına düştü) paywall açılınca TEKRAR dener. Böylece "Planlar
    // yükleniyor…" ekranında sonsuza kadar kalınmaz; mağaza uyandığında
    // fiyatlar gelir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Iap.instance.retryIfNeeded();
    });
  }

  @override
  void dispose() {
    // Paywall'ı görüp satın almadan çıkanlar — huninin en büyük kaybı burada
    // ve daha önce hiç ölçülmüyordu.
    if (!_purchaseAttempted) {
      Analytics.instance.log(Ev.paywallDismiss, {
        'source': widget.source,
        'selected_plan': _selectedId,
      });
    }
    super.dispose();
  }

  /// Pro'nun GERÇEKTEN sunduğu faydalar.
  ///
  /// DİKKAT — bu liste bilerek kısa: her madde kodda karşılığı olan, gerçek
  /// bir kilidi anlatmalı. Önceki hâli 8 madde sayıyordu ama çoğu doğru
  /// değildi: "Akıllı Hatırlatma" ve "AI İçgörüleri" diye bir özellik
  /// uygulamada HİÇ YOK; "Gelişmiş İstatistik", "Tüm Başarımlar" ve
  /// "Dışa Aktar" ise ücretsiz kullanıcıda ZATEN tamamen açık (bkz.
  /// analytics_screen.dart, achievements_screen.dart, settings_screen.dart —
  /// hiçbirinde Pro kontrolü yok). Var olmayan/kilitli olmayan özellikleri
  /// abonelik karşılığında vaat etmek App Store (2.3.1 doğru üstveri /
  /// 3.1.2) ve Google Play politikalarında yanıltıcı beyan sayılır ve
  /// incelemede ret sebebidir; ayrıca satın alan kullanıcı vaat edileni
  /// bulamayınca iade + düşük puan bırakır.
  ///
  /// En değerli gerçek fayda olan REKLAMSIZ kullanım ise listede hiç yoktu;
  /// başa alındı (bkz. root_shell.dart `if (!s.hasPro) const AdBanner()`
  /// ve ads.dart Interstitials.maybeShow → isPro).
  List<(IconData, String, String)> get _features => [
        (Icons.block_rounded, t('Reklamsız Deneyim', 'No Ads'),
            t('Banner ve tam ekran reklamların tamamı kapanır',
                'All banner and full-screen ads disappear')),
        (Icons.palette_rounded, t('Tüm Temalar', 'All Themes'),
            t('Kilitli premium temaların tamamı açılır',
                'Unlock every premium theme')),
        (Icons.people_alt_rounded, t('Sorumluluk Ortağı', 'Accountability Partner'),
            t('Arkadaşınla serilerini paylaş, birlikte devam et',
                'Share your streaks with a friend and keep each other going')),
        (Icons.psychology_rounded, t('Kişisel İçgörüler', 'Personal Insights'),
            t('Risk pencerelerin ve tetikleyici haritan — kendi verinden',
                'Your risk windows and trigger map — from your own data')),
        (Icons.timeline_rounded,
            t('Tam İyileşme Yolculuğu', 'Full Recovery Timeline'),
            t('Bıraktığın şeye özel tüm sağlık kilometre taşlarını gör',
                'See every health milestone for what you quit')),
        (Icons.insights_rounded, t('Haftalık Rapor', 'Weekly Report'),
            t('Her pazar: haftanın deseni ve gelecek hafta için odağın',
                'Every Sunday: your week\'s pattern and next week\'s focus')),
      ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: RC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RG.header),
        child: SafeArea(
          child: ListView(
            padding: rContentPadding(context, const EdgeInsets.fromLTRB(20, 8, 20, 40)),
            children: [
              rutinAppBar(context, t('Rutin Pro', 'Rutin Pro')),
              const SizedBox(height: 22),

              _hero(s),
              const SizedBox(height: 26),

              Text(t('Neler var', "What's included"), style: RText.title),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                // 4 madde = 2 satır. Açıklamalar öncekinden uzun olduğu için
                // kartlar biraz daha yüksek (oran küçüldü) — kısa oranla
                // metin taşıp overflow şeridi çıkıyordu.
                childAspectRatio: 0.86,
                children: _features.map(_feature).toList(),
              ),
              const SizedBox(height: 20),

              // ---- Plan seçimi + CTA (Pro değilse) ----
              if (!s.isPro)
                AnimatedBuilder(
                  animation: Iap.instance,
                  builder: (context, _) {
                    final pending = Iap.instance.purchasePending;
                    // Fiyat kartlarında GÖSTERİLEN fiyat ile satın alma
                    // ekranındaki fiyatın FARKLI olması ihtimalini tamamen
                    // ortadan kaldırmak için: fiyatları asla koda gömülü sabit
                    // bir değerden göstermeyiz. Yalnızca mağazadan gelen
                    // gerçek yerelleştirilmiş fiyatı gösteririz — bu, satın
                    // alma ekranındaki fiyatla AYNI kaynaktır, dolayısıyla
                    // birbirinden farklı olamaz. Ürünler henüz yüklenmediyse
                    // (mağaza cevabı beklenirken) sabit bir rakam yerine
                    // yükleniyor durumu gösterilir.
                    final yearly = Iap.instance.productFor(Iap.yearlyId);
                    final monthly = Iap.instance.productFor(Iap.monthlyId);

                    // EN AZ BİR plan geldiyse ekran çalışır.
                    //
                    // Eskiden koşul `yearly != null && monthly != null` idi:
                    // İKİSİ birden gerekiyordu. Sahada bu, tek bir ürünün
                    // mağazadan gelmemesi hâlinde paywall'ın TAMAMEN
                    // kapanmasına yol açtı — yıllık plan sorunsuz gelse bile
                    // kullanıcı hiçbir şey satın alamıyordu. App Store da
                    // bunu "an error is shown when trying to access the
                    // in-app purchases" diyerek 2.1(b) altında reddetti.
                    //
                    // Doğru davranış: gelen planları göster, gelmeyeni gizle
                    // (ömür boyu ürünü için zaten böyle yapılıyordu). Hiçbir
                    // plan gelmediyse hata durumuna düş.
                    //
                    // Kısmi gösterim güvenli: fiyat HER ZAMAN mağazadan
                    // gelen gerçek değer, satın alma da yalnızca gösterilen
                    // ürün için başlatılabiliyor.
                    final ready = yearly != null || monthly != null;
                    if (!ready) {
                      // BEKLEME ile BAŞARISIZLIK farklı şeylerdir; eskiden
                      // ikisi de aynı sonsuz "yükleniyor" göstergesine
                      // düşüyordu. Mağaza hiç ürün döndürmediğinde ekran
                      // sonsuza kadar dönüyor, kullanıcı satın alamıyor,
                      // sebebini öğrenemiyor, zaten ödemişse "geri yükle"ye
                      // ulaşamıyor ve ZORUNLU yasal bağlantılar hiç
                      // görünmüyordu — App Store 3.1.2 bunları abonelik
                      // sunulan ekranda şart koşuyor.
                      if (!Iap.instance.productsLoadAttempted) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                  color: RC.purpleBright),
                              const SizedBox(height: 16),
                              Text(
                                  t('Planlar yükleniyor…', 'Loading plans…'),
                                  style: TextStyle(
                                      color: RC.muted, fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      return _plansUnavailable(context);
                    }

                    // Hangi planlar gösterilecek ve seçim geçerli mi
                    // (bkz. resolvePaywallPlans — saf ve test edilmiş).
                    _selectedId = resolvePaywallPlans(
                      hasYearly: yearly != null,
                      hasMonthly: monthly != null,
                      currentSelection: _selectedId,
                    ).selected;

                    return Column(
                      children: [
                        if (yearly != null) ...[
                          _planCard(
                            id: Iap.yearlyId,
                            title: t('Yıllık', 'Yearly'),
                            price: yearly.price,
                            subtitle: _yearlySubtitle(),
                            badge: t('EN AVANTAJLI', 'BEST VALUE'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (monthly != null)
                          _planCard(
                            id: Iap.monthlyId,
                            title: t('Aylık', 'Monthly'),
                            price: monthly.price,
                            subtitle: t('her ay yenilenir', 'billed monthly'),
                          ),
                        const SizedBox(height: 18),
                        if (pending)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: RC.purpleBright),
                            ),
                          )
                        else
                          RButton(_ctaLabel(), onTap: () => _buy(context)),
                        const SizedBox(height: 10),
                        Text(
                            t('İstediğin an iptal edebilirsin',
                                'Cancel anytime'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: RC.muted, fontSize: 13)),
                        const SizedBox(height: 14),
                        _subscriptionDisclosure(yearly, monthly),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: () {
                            _purchaseAttempted = true;
                            Analytics.instance.log(Ev.purchaseRestore,
                                {'source': widget.source});
                            Iap.instance.restore();
                          },
                          child: Center(
                            child: Text(
                                t('Satın Alımları Geri Yükle',
                                    'Restore Purchases'),
                                style: TextStyle(
                                    color: RC.muted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _legalLinks(context),
                      ],
                    );
                  },
                ),

              // Ödüllü reklam: 4 saat ücretsiz Pro (kalıcı Pro değilse).
              if (!s.isPro) ..._rewardedOffer(context, s),
            ],
          ),
        ),
      ),
    );
  }

  /// Abonelik koşullarının AÇIK beyanı.
  ///
  /// Ana buton satın almaya çağırıyor ama ne kadar, hangi sıklıkla ve
  /// otomatik olarak mı ücretlendirileceği hiçbir yerde yazmıyordu. Bu,
  /// App Store Review Guideline 3.1.2'nin ("abonelik süresi,
  /// fiyatı ve otomatik yenileme koşulları satın alma öncesinde açıkça
  /// gösterilmeli") doğrudan ihlali ve tüketici mevzuatı açısından da
  /// risklidir. Ayrıca kullanıcı beklemediği bir tahsilatla karşılaşınca
  /// iade + tek yıldız bırakır; şeffaflık uzun vadede dönüşümü DÜŞÜRMEZ,
  /// iade ve churn'ü düşürür.
  Widget _subscriptionDisclosure(
      ProductDetails? yearly, ProductDetails? monthly) {
    final String text;
    if (_selectedId == Iap.yearlyId) {
      final price = yearly?.price ?? '';
      text = kYearlyHasIntroTrial
          ? t(
              '7 günlük deneme ücretsizdir. Deneme bitiminde $price yıllık olarak tahsil edilir ve iptal etmediğin sürece her yıl otomatik yenilenir. İptali, denemenin bitiminden en az 24 saat önce mağaza hesabının abonelik ayarlarından yapabilirsin.',
              'The 7-day trial is free. When it ends you\'ll be charged $price per year, renewing automatically each year unless cancelled. Cancel at least 24 hours before the trial ends from your store account\'s subscription settings.')
          : t(
              '$price yıllık olarak tahsil edilir ve iptal etmediğin sürece her yıl otomatik yenilenir. İptali mağaza hesabının abonelik ayarlarından yapabilirsin.',
              '$price is charged yearly and renews automatically each year unless cancelled. Cancel from your store account\'s subscription settings.');
    } else {
      final price = monthly?.price ?? '';
      text = t(
          '$price aylık olarak tahsil edilir ve iptal etmediğin sürece her ay otomatik yenilenir. İptali mağaza hesabının abonelik ayarlarından yapabilirsin.',
          '$price is charged monthly and renews automatically each month unless cancelled. Cancel from your store account\'s subscription settings.');
    }
    return Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(color: RC.faint, fontSize: 11, height: 1.45));
  }

  /// Ekranın üst bloğu: ikon + başlık + alt başlık. Metinler Pro durumuna
  /// göre değişir.
  Widget _hero(AppState s) => Center(
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: RG.purpleBtn,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: RC.purple.withValues(alpha: 0.5), blurRadius: 30),
                ],
              ),
              child: const Icon(Icons.diamond_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
                s.isPro
                    ? t('Pro aktif 🎉', 'Pro is active 🎉')
                    : t('Dikkatini dağıtan hiçbir şey kalmasın',
                        'Nothing standing between you and your goal'),
                style: RText.h2,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
                s.isPro
                    ? t('Tüm özelliklerin kilidi açık.',
                        'All features are unlocked.')
                    : t('Reklamsız, kesintisiz bir Rutin — ve gelecek her yeni özellik.',
                        'An ad-free, distraction-free Rutin — plus every feature to come.'),
                style: RText.muted,
                textAlign: TextAlign.center),
          ],
        ),
      );

  /// Ödüllü reklam karşılığı 4 saatlik Pro — abonelik ALTERNATİFİ değil,
  /// ödemeye hazır olmayan kullanıcıyı ürünle tanıştırma yolu.
  List<Widget> _rewardedOffer(BuildContext context, AppState s) => [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: RC.stroke)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(t('ya da', 'or'),
                  style: TextStyle(color: RC.muted, fontSize: 13)),
            ),
            Expanded(child: Divider(color: RC.stroke)),
          ],
        ),
        const SizedBox(height: 16),
        RCard(
          color: RC.tintAmber,
          border: RC.amber.withValues(alpha: 0.4),
          onTap: () => _watchRewarded(context),
          child: Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 30, color: RC.amber),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        s.proTrialActive
                            ? t('4 Saat Daha Kazan', 'Get 4 More Hours')
                            : t('4 Saat Ücretsiz Pro', '4 Hours of Pro, Free'),
                        style: TextStyle(
                            color: RC.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        s.proTrialActive
                            ? t(
                                'Kalan: ${_fmtRemaining(s.proTrialRemaining!)} · reklam izle, süreyi yenile',
                                'Left: ${_fmtRemaining(s.proTrialRemaining!)} · watch an ad to renew')
                            : t('Kısa bir reklam izle, tüm Pro açılsın',
                                'Watch a short ad to unlock all of Pro'),
                        style: TextStyle(color: RC.muted, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill, color: RC.amber, size: 28),
            ],
          ),
        ),
      ];

  /// Gizlilik politikası + kullanım koşulları — abonelik satılan ekranda
  /// bulunması ZORUNLU (App Store 3.1.2). Uygulamada hiç yoktu.
  /// Planlar mağazadan alınamadığında gösterilir.
  ///
  /// Üç şeyi mutlaka barındırır:
  ///   1. Ne olduğunu söyleyen açık bir mesaj (sonsuz spinner yerine),
  ///   2. "Tekrar Dene" — sorun geçiciyse kullanıcı ekrandan çıkmadan çözer,
  ///   3. "Satın Alımları Geri Yükle" + yasal bağlantılar — ZATEN ödemiş
  ///      kullanıcı burada kilitli kalmamalı ve App Store 3.1.2, abonelik
  ///      sunulan ekranda bu bağlantıları şart koşuyor.
  Widget _plansUnavailable(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Standart hata durumu bileşeni (RError). Burada REmpty'nin ikonu,
          // eylem etiketi ve davranışı elle tekrarlanıyordu — RError zaten
          // tam olarak bu üçünü kapsıyor.
          RError(
            title: t('Planlar şu an yüklenemedi',
                "Couldn't load the plans"),
            message: t(
                'Mağazaya ulaşılamıyor. İnternet bağlantını kontrol edip tekrar deneyebilirsin.',
                "We can't reach the store. Check your connection and try again."),
            onRetry: () => Iap.instance.retryProducts(),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              _purchaseAttempted = true;
              Analytics.instance
                  .log(Ev.purchaseRestore, {'source': widget.source});
              Iap.instance.restore();
            },
            child: Center(
              child: Text(
                  t('Satın Alımları Geri Yükle', 'Restore Purchases'),
                  style: TextStyle(
                      color: RC.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 14),
          _legalLinks(context),
        ],
      ),
    );
  }

  Widget _legalLinks(BuildContext context) {
    Widget link(String label, String url) => GestureDetector(
          onTap: () => openLegalUrl(context, url),
          child: Text(label,
              style: TextStyle(
                  color: RC.muted,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: RC.muted)),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        link(t('Gizlilik Politikası', 'Privacy Policy'), kPrivacyPolicyUrl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('·', style: TextStyle(color: RC.faint, fontSize: 12)),
        ),
        link(t('Kullanım Koşulları', 'Terms of Use'), kTermsOfUseUrl),
      ],
    );
  }

  static String _fmtRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}s ${m}dk';
    return '${m}dk';
  }

  /// Seçili plana göre ana buton metni.
  String _ctaLabel() {
    // Deneme yalnızca YILLIK planda sunulur (bkz. ABONELIK-STRATEJISI.md):
    // deneme maliyetini en yüksek LTV'li plana yönlendirmek standart ve
    // sağlıklı bir yaklaşımdır.
    if (_selectedId == Iap.yearlyId) {
      // Deneme yalnızca mağazada GERÇEKTEN tanımlıysa vaat edilir
      // (bkz. kYearlyHasIntroTrial).
      return kYearlyHasIntroTrial
          ? t('7 Gün Ücretsiz Dene', 'Start 7-Day Free Trial')
          : t('Yıllık Planı Başlat', 'Start Yearly Plan');
    }
    return t('Aylık Planı Başlat', 'Start Monthly Plan');
  }

  /// Yıllık planın aylığa göre avantajını, MAĞAZADAN GELEN gerçek fiyatlarla
  /// hesaplar. Fiyatlar yerelleştirilmiş metin olduğu için (₺749,00 / $39.99)
  /// içlerinden sayıyı ayıklamak gerekir; ayıklanamazsa genel bir ifadeye
  /// düşülür — asla yanlış bir yüzde gösterilmez.
  String _yearlySubtitle() {
    final monthly = _parsePrice(Iap.instance.productFor(Iap.monthlyId)?.price);
    final yearly = _parsePrice(Iap.instance.productFor(Iap.yearlyId)?.price);
    if (monthly == null || yearly == null || monthly <= 0 || yearly <= 0) {
      return t('yılda bir ödeme · en düşük aylık maliyet',
          'billed yearly · lowest monthly cost');
    }
    final saving = (1 - (yearly / (monthly * 12))) * 100;
    if (saving < 5) {
      return t('yılda bir ödeme', 'billed yearly');
    }
    return t('aylık plana göre %${saving.round()} tasarruf',
        'save ${saving.round()}% vs monthly');
  }

  /// "₺749,00", "$39.99", "39,99 €" gibi yerelleştirilmiş fiyat metninden
  /// sayısal değeri çıkarır.
  static double? _parsePrice(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleaned.isEmpty) return null;
    // Son ayırıcı ondalık kabul edilir (hem 1.499,00 hem 1,499.00 için).
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    String normalized;
    if (lastComma > lastDot) {
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = cleaned.replaceAll(',', '');
    }
    return double.tryParse(normalized);
  }

  /// Seçilebilir plan kartı. Seçili olan vurgulanır; "badge" verilirse
  /// (yıllık planda "EN AVANTAJLI") sağ üstte rozet gösterilir.
  Widget _planCard({
    required String id,
    required String title,
    required String price,
    required String subtitle,
    String? badge,
  }) {
    final selected = _selectedId == id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedId = id);
        Analytics.instance
            .log(Ev.planSelect, {'plan': id, 'source': widget.source});
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? RC.tintPurple : RC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? RC.purpleBright
                    : RC.stroke,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? RC.purpleBright : RC.muted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: RC.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: RC.muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected ? RC.purpleBright : RC.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -8,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: RG.purpleBtn,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
              ),
            ),
        ],
      ),
    );
  }

  void _watchRewarded(BuildContext context) {
    final state = context.read<AppState>();
    _purchaseAttempted = true;
    Analytics.instance.log(Ev.rewardedStart, {'source': widget.source});
    Rewarded.instance.show(
      onReward: () {
        Analytics.instance.log(Ev.rewardedGranted);
        state.grantProTrial();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text(t('4 saatlik Pro açıldı! 🎉',
                  '4 hours of Pro unlocked! 🎉'))));
      },
      onUnavailable: () {
        Analytics.instance.log(Ev.rewardedUnavailable);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text(t(
                  'Şu an gösterilecek reklam yok. Birazdan tekrar dene.',
                  'No ad available right now. Try again shortly.'))));
      },
    );
  }

  void _buy(BuildContext context) {
    // Kullanıcının SEÇTİĞİ planı satın al (önceden her zaman aylık
    // satın alınıyordu — yıllık seçilse bile).
    if (Iap.instance.available &&
        Iap.instance.productFor(_selectedId) != null) {
      _purchaseAttempted = true;
      Analytics.instance.log(
          Ev.purchaseStart, {'plan': _selectedId, 'source': widget.source});
      Iap.instance.buy(_selectedId);
      return;
    }
    // Mağazaya ulaşılamadığı için satın alma HİÇ BAŞLAYAMADI. Bu, sessizce
    // kaybedilen bir satıştır ve ölçülmeden fark edilmesi imkânsızdır.
    Analytics.instance.log(Ev.purchaseFail, {
      'plan': _selectedId,
      'source': widget.source,
      'reason': 'store_unavailable',
    });
    if (kDebugMode) {
      // Mağazaya ulaşılamıyor (öykünücü/masaüstü) — yalnızca DEBUG build'de
      // test için Pro'yu aç. Release build'de asla ücretsiz açılmaz.
      context.read<AppState>().activatePro();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(t('Pro etkinleştirildi (yalnızca debug test modu).',
                'Pro activated (debug test mode only).'))));
      return;
    }
    // Release build + mağazaya ulaşılamıyor: sessizce Pro açmak yerine
    // kullanıcıyı bilgilendir.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(t('Mağazaya şu anda ulaşılamıyor. Lütfen tekrar deneyin.',
              'The store is unavailable right now. Please try again.'))));
  }

  Widget _feature((IconData, String, String) f) {
    final (icon, title, desc) = f;
    return RCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: RC.purple),
          const SizedBox(height: 14),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: 6),
          // Esnek + ellipsis: farklı dil/yazı tipi ölçeklerinde (kullanıcı
          // sistem yazı boyutunu büyütmüşse) sabit yükseklikli grid
          // hücresinde metin taşıp overflow şeridi çıkarmasın.
          Flexible(
            child: Text(desc,
                overflow: TextOverflow.ellipsis,
                maxLines: 4,
                style:
                    TextStyle(color: RC.muted, fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
